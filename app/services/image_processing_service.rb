class ImageProcessingService
  THUMBNAIL_SIZES = {
    thumbnail: { width: 200, height: 200 },
    small: { width: 400, height: 400 },
    medium: { width: 600, height: 600 },
    large: { width: 1200, height: 1200 },
    xl: { width: 1920, height: 1920 }
  }.freeze

  def initialize(photo)
    @photo = photo
  end

  def process_all_variants
    return unless @photo.image.attached?

    # Ensure the blob is analyzed first
    analyze_image unless @photo.image.blob.analyzed?

    # Process each thumbnail size
    THUMBNAIL_SIZES.each do |size_name, dimensions|
      process_variant(size_name, dimensions)
    end

    # Update photo processing status
    @photo.update_column(:processing_completed_at, Time.current)
    
    Rails.logger.info "All variants processed for Photo #{@photo.id}"
  end

  def process_variant(size_name, dimensions)
    start_time = Time.current
    
    variant = @photo.image.variant(
      resize_to_limit: [dimensions[:width], dimensions[:height]],
      format: :jpeg,
      quality: size_name == :thumbnail ? 85 : 90
    )
    
    # Force processing by calling processed
    variant.processed
    
    processing_time = Time.current - start_time
    Rails.logger.info "Processed #{size_name} variant for Photo #{@photo.id} in #{processing_time.round(2)}s"
    
    variant
  rescue StandardError => e
    Rails.logger.error "Failed to process #{size_name} variant for Photo #{@photo.id}: #{e.message}"
    raise
  end

  def analyze_image
    @photo.image.analyze
    Rails.logger.info "Analyzed image for Photo #{@photo.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to analyze image for Photo #{@photo.id}: #{e.message}"
    raise
  end

  # Class method to get variant for a specific size
  def self.variant_for_size(photo, size)
    return nil unless photo.image.attached?
    
    dimensions = THUMBNAIL_SIZES[size.to_sym]
    return nil unless dimensions

    quality = size.to_sym == :thumbnail ? 85 : 90
    
    photo.image.variant(
      resize_to_limit: [dimensions[:width], dimensions[:height]],
      format: :jpeg,
      quality: quality
    )
  end

  # Check if all variants are processed
  def self.all_variants_processed?(photo)
    return false unless photo.image.attached?
    return false unless photo.processing_completed_at.present?
    
    THUMBNAIL_SIZES.keys.all? do |size_name|
      variant = variant_for_size(photo, size_name)
      variant&.processed&.attached?
    rescue StandardError
      false
    end
  end

  # Get the best available variant for a size (fallback to smaller if not ready)
  def self.best_available_variant(photo, requested_size)
    return nil unless photo.image.attached?

    # Try requested size first
    variant = variant_for_size(photo, requested_size)
    return variant if variant_ready?(variant)

    # Fallback to smaller sizes if requested size isn't ready
    fallback_order = case requested_size.to_sym
    when :xl then [:large, :medium, :small, :thumbnail]
    when :large then [:medium, :small, :thumbnail]
    when :medium then [:small, :thumbnail]
    when :small then [:thumbnail]
    else []
    end

    fallback_order.each do |fallback_size|
      variant = variant_for_size(photo, fallback_size)
      return variant if variant_ready?(variant)
    end

    # Return original if no variants are ready
    photo.image
  end

  private

  def self.variant_ready?(variant)
    return false unless variant
    
    variant.processed.attached?
  rescue StandardError
    false
  end
end