# Represents a photo uploaded by a user that can belong to multiple albums.
#
# Photos store image files using Active Storage and automatically extract
# EXIF metadata including date taken, GPS coordinates, and camera information.
# Multiple image variants are generated for different display sizes.
#
# == Associations
# * belongs_to :user - The user who uploaded the photo
# * has_many :albums - Albums containing this photo (through album_photos)
# * has_many :bulk_uploads - Bulk uploads this photo belongs to
#
# == Validations
# * title: Maximum 255 characters
# * description: Maximum 1000 characters
# * image: Required, must be PNG/JPEG/GIF, under 50MB
#
# == EXIF Data
# Automatically extracts metadata including:
# * taken_at: Date/time photo was taken
# * latitude/longitude: GPS coordinates
# * camera_make/camera_model: Camera information
# * metadata: Full EXIF data as JSON
#
class Photo < ApplicationRecord
  belongs_to :user

  # Active Storage associations
  has_one_attached :image

  # Album associations - photos can belong to multiple albums
  has_many :album_photos, dependent: :destroy
  has_many :albums, through: :album_photos

  # Bulk upload associations - tracks which bulk upload session created this photo
  has_many :bulk_upload_photos, dependent: :destroy
  has_many :bulk_uploads, through: :bulk_upload_photos

  # Validations
  validates :title, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validates :location, length: { maximum: 255 }
  validates :image, presence: true, content_type: [ "image/png", "image/jpeg", "image/gif" ],
                    size: { less_than: 50.megabytes }

  # Image processing lifecycle. "pending" and "processing" are transient;
  # "ready" and "failed" are terminal, so the UI knows when to stop waiting.
  PROCESSING_STATES = %w[pending processing ready failed].freeze
  MAX_PROCESSING_ATTEMPTS = 3

  validates :processing_state, inclusion: { in: PROCESSING_STATES }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_taken, -> { order(taken_at: :desc, created_at: :desc) }
  scope :processing_failed, -> { where(processing_state: "failed") }
  scope :awaiting_processing, -> { where(processing_state: %w[pending processing]) }

  before_save :extract_basic_metadata
  # Callbacks
  before_destroy :remove_cover_photo_references, prepend: true
  after_destroy :reorder_album_positions
  after_create_commit :process_image_variants
  after_create_commit :extract_metadata_async

  def processing_pending?
    processing_state == "pending"
  end

  def processing?
    processing_state == "processing"
  end

  def processing_ready?
    processing_state == "ready"
  end

  def processing_failed?
    processing_state == "failed"
  end

  # True once the outcome is known either way — the signal the UI needs to stop
  # polling. Previously photos/show polled every 2s forever.
  def processing_settled?
    processing_ready? || processing_failed?
  end

  def retryable?
    processing_failed? && processing_attempts < MAX_PROCESSING_ATTEMPTS
  end

  def mark_processing!
    update_columns(
      processing_state: "processing",
      processing_attempts: processing_attempts + 1,
      updated_at: Time.current
    )
  end

  def mark_processing_ready!
    update_columns(
      processing_state: "ready",
      processing_error: nil,
      processing_completed_at: Time.current,
      updated_at: Time.current
    )
  end

  def mark_processing_failed!(error)
    update_columns(
      processing_state: "failed",
      processing_error: error.to_s.truncate(1000),
      updated_at: Time.current
    )
  end

  def retry_processing!
    update_columns(
      processing_state: "pending",
      processing_error: nil,
      updated_at: Time.current
    )
    ImageProcessingJob.perform_async(id)
  end

  # Image variants for different display sizes using the service
  def thumbnail
    ImageProcessingService.variant_for_size(self, :thumbnail)
  end

  def small
    ImageProcessingService.variant_for_size(self, :small)
  end

  def medium
    ImageProcessingService.variant_for_size(self, :medium)
  end

  def large
    ImageProcessingService.variant_for_size(self, :large)
  end

  # Per-instance cache of resolved short URLs, populated either lazily or in bulk
  # by ShortUrl.warm_for_photos. Without it a grid re-queried short_urls for every
  # photo and every variant on every render.
  def cached_short_url(variant)
    record = short_url_cache[variant.to_s]
    return nil if record.nil?

    # Never hand back a stale entry: a long-lived Photo object could otherwise
    # keep serving a short URL that has since expired.
    if record.expired?
      short_url_cache.delete(variant.to_s)
      return nil
    end

    record
  end

  def cache_short_url(variant, record)
    short_url_cache[variant.to_s] = record
  end

  def short_url_cache
    @short_url_cache ||= {}
  end

  # Short URL methods for variants
  def short_thumbnail_url
    ShortUrl.for_photo_variant(self, :thumbnail).short_path
  end

  def short_small_url
    ShortUrl.for_photo_variant(self, :small).short_path
  end

  def short_medium_url
    ShortUrl.for_photo_variant(self, :medium).short_path
  end

  def short_large_url
    ShortUrl.for_photo_variant(self, :large).short_path
  end

  def short_xl_url
    ShortUrl.for_photo_variant(self, :xl).short_path
  end

  def short_original_url
    ShortUrl.for_photo_variant(self, :original).short_path
  end

  def xl
    ImageProcessingService.variant_for_size(self, :xl)
  end

  # Get the best available variant for a specific size
  def best_variant(size)
    ImageProcessingService.best_available_variant(self, size)
  end

  # Check if image processing is complete
  def image_processed?
    image.attached? && image.blob.analyzed?
  end

  # Check if background processing is complete
  def background_processing_complete?
    processing_completed_at.present?
  end

  # Check if all variants are ready
  def all_variants_ready?
    ImageProcessingService.all_variants_processed?(self)
  end

  # Get image dimensions if available
  def image_dimensions
    return nil unless image_processed?

    metadata = image.blob.metadata
    return nil unless metadata["width"] && metadata["height"]

    "#{metadata['width']} × #{metadata['height']}"
  end

  # A photo is visible to its owner, and to anyone who can reach it through an
  # album they are allowed to see. Photos that sit in no shared album stay private.
  def viewable_by?(viewer)
    return false unless viewer
    return true if user_id == viewer.id

    Album.accessible_to(viewer)
         .joins(:album_photos)
         .exists?(album_photos: { photo_id: id })
  end

  # Get formatted file size
  def formatted_file_size
    return nil unless file_size

    if file_size < 1.megabyte
      "#{(file_size / 1.kilobyte.to_f).round(1)} KB"
    else
      "#{(file_size / 1.megabyte.to_f).round(1)} MB"
    end
  end

  private

  def extract_basic_metadata
    return unless image.attached?

    self.original_filename = image.blob.filename.to_s
    self.file_size = image.blob.byte_size
    self.content_type = image.blob.content_type

    # Don't extract EXIF data here - let the background job handle it
  end

  # These run after commit, so the Photo row already exists. Letting a queue
  # outage raise here returned HTTP 500 for an upload that had actually
  # succeeded, and the user re-uploaded and created silent duplicates. Leave the
  # photo in its pending state instead — it stays visible (the streamer builds
  # variants on demand) and can be retried.
  def extract_metadata_async
    ExtractPhotoMetadataJob.perform_async(id)
  rescue StandardError => e
    Rails.logger.error "Could not enqueue metadata extraction for Photo #{id}: #{e.class}: #{e.message}"
  end

  def process_image_variants
    ImageProcessingJob.perform_async(id)
  rescue StandardError => e
    Rails.logger.error "Could not enqueue image processing for Photo #{id}: #{e.class}: #{e.message}"
  end

  def remove_cover_photo_references
    # Store album IDs for later reordering (after dependent: :destroy happens)
    @albums_to_reorder = albums.pluck(:id)

    # Handle album cover photo reassignment
    affected_albums = Album.where(cover_photo_id: id)

    affected_albums.each do |album|
      # Find a new cover photo (excluding this one)
      new_cover = album.ordered_photos.where.not(id: id).first
      album.update_column(:cover_photo_id, new_cover&.id)
    end
  end

  def reorder_album_positions
    return unless @albums_to_reorder&.any?

    Album.where(id: @albums_to_reorder).find_each(&:reorder_positions!)
  end
end
