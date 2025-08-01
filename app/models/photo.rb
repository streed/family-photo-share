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

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_taken, -> { order(taken_at: :desc, created_at: :desc) }

  before_save :extract_basic_metadata
  # Callbacks
  before_destroy :remove_cover_photo_references, prepend: true
  after_destroy :reorder_album_positions
  after_create_commit :process_image_variants
  after_create_commit :extract_metadata_async

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

  def extract_metadata_async
    # Schedule background job to extract EXIF metadata
    ExtractPhotoMetadataJob.perform_async(id)
  end

  def process_image_variants
    # Schedule background image processing
    ImageProcessingJob.perform_async(id)
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
    # Reorder positions in all albums that contained this photo
    # @albums_to_reorder is set in remove_cover_photo_references
    return unless @albums_to_reorder&.any?

    Album.where(id: @albums_to_reorder).each do |album|
      album.send(:reorder_positions)
    end
  end
end
