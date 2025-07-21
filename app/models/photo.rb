class Photo < ApplicationRecord
  belongs_to :user

  # Active Storage associations
  has_one_attached :image
  
  # Album associations
  has_many :album_photos, dependent: :destroy
  has_many :albums, through: :album_photos

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validates :location, length: { maximum: 255 }
  validates :image, presence: true, content_type: ['image/png', 'image/jpeg', 'image/gif'],
                    size: { less_than: 10.megabytes }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_taken, -> { order(taken_at: :desc, created_at: :desc) }

  # Callbacks
  before_destroy :remove_cover_photo_references
  before_save :extract_basic_metadata
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
    return nil unless metadata['width'] && metadata['height']
    
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
    # Remove this photo as cover photo from any albums before deletion
    Album.where(cover_photo_id: id).update_all(cover_photo_id: nil)
  end
end