class BulkImageProcessingJob
  include Sidekiq::Job
  sidekiq_options retry: 1, queue: 'bulk_processing'

  def perform(batch_size = 10)
    Rails.logger.info "Starting bulk image processing"
    
    # Find photos that haven't been processed yet
    unprocessed_photos = Photo.joins(:image_attachment)
                              .where(processing_completed_at: nil)
                              .limit(batch_size)

    if unprocessed_photos.empty?
      Rails.logger.info "No unprocessed photos found"
      return
    end

    Rails.logger.info "Processing #{unprocessed_photos.count} photos"
    
    unprocessed_photos.find_each do |photo|
      begin
        ImageProcessingJob.perform_async(photo.id)
        Rails.logger.info "Queued processing for Photo #{photo.id}"
      rescue StandardError => e
        Rails.logger.error "Failed to queue processing for Photo #{photo.id}: #{e.message}"
      end
    end

    # Schedule next batch if there are more photos to process
    remaining_count = Photo.joins(:image_attachment)
                           .where(processing_completed_at: nil)
                           .count

    if remaining_count > batch_size
      Rails.logger.info "Scheduling next batch, #{remaining_count - batch_size} photos remaining"
      BulkImageProcessingJob.perform_in(30.seconds, batch_size)
    else
      Rails.logger.info "Bulk processing completed"
    end
  end
end