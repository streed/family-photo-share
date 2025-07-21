class ImageProcessingJob
  include Sidekiq::Job
  sidekiq_options retry: 3, queue: 'image_processing'

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return unless photo.image.attached?

    Rails.logger.info "Starting image processing for Photo #{photo_id}"
    
    # Process all variants in background
    ImageProcessingService.new(photo).process_all_variants
    
    Rails.logger.info "Completed image processing for Photo #{photo_id}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Photo #{photo_id} not found during image processing"
  rescue StandardError => e
    Rails.logger.error "Error processing image for Photo #{photo_id}: #{e.message}"
    raise # Re-raise to trigger Sidekiq retry
  end
end