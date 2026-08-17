class ImageProcessingJob
  include Sidekiq::Job
  sidekiq_options retry: 3, queue: "image_processing"

  def perform(photo_id)
    photo = Photo.find(photo_id)
    return unless photo.image.attached?

    Rails.logger.info "Starting image processing for Photo #{photo_id}"
    photo.mark_processing!

    ImageProcessingService.new(photo).process_all_variants

    photo.mark_processing_ready!
    Rails.logger.info "Completed image processing for Photo #{photo_id}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Photo #{photo_id} not found during image processing"
  rescue StandardError => e
    Rails.logger.error "Error processing image for Photo #{photo_id}: #{e.message}"
    # Record the failure so the photo doesn't sit in "processing" forever if the
    # retries are exhausted. A later attempt overwrites this on success.
    photo&.mark_processing_failed!(e.message)
    raise # Re-raise to trigger Sidekiq retry
  end
end
