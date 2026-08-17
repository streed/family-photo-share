class BulkImageProcessingJob
  include Sidekiq::Job
  sidekiq_options retry: 1, queue: "bulk_processing"

  # Only sweep photos that have been sitting unprocessed for a while. A photo
  # uploaded seconds ago already has its own ImageProcessingJob in flight;
  # picking it up here would queue the work twice.
  STALE_AFTER = 30.minutes

  # Repairs photos whose image processing never completed — a job lost to a
  # crash, a Redis outage during upload, or an exhausted retry.
  #
  # The previous version queued a batch and then immediately recounted photos
  # with processing_completed_at IS NULL. Those counts could not have changed
  # yet, because the jobs it had just enqueued had not run, so it rescheduled
  # itself every 30 seconds forever and re-queued the same photos each time.
  # Marking each photo as processing when it is enqueued is what makes the sweep
  # terminate: the next pass no longer sees it.
  def perform(batch_size = 10)
    Rails.logger.info "Starting bulk image processing sweep"

    photos = stale_photos.limit(batch_size).to_a

    if photos.empty?
      Rails.logger.info "No stranded photos found"
      return 0
    end

    queued = 0
    photos.each do |photo|
      photo.mark_processing!
      ImageProcessingJob.perform_async(photo.id)
      queued += 1
      Rails.logger.info "Queued processing for Photo #{photo.id}"
    rescue StandardError => e
      # Put it back so a later sweep can retry rather than losing it silently.
      photo.update_columns(processing_state: "pending", updated_at: STALE_AFTER.ago)
      Rails.logger.error "Failed to queue processing for Photo #{photo.id}: #{e.message}"
    end

    remaining = stale_photos.count
    if queued.positive? && remaining.positive?
      Rails.logger.info "Scheduling next batch, #{remaining} photos remaining"
      BulkImageProcessingJob.perform_in(30.seconds, batch_size)
    else
      Rails.logger.info "Bulk processing sweep complete"
    end

    queued
  end

  private

  def stale_photos
    Photo.joins(:image_attachment)
         .where(processing_state: %w[pending failed])
         .where(photos: { processing_attempts: ...Photo::MAX_PROCESSING_ATTEMPTS })
         .where(photos: { updated_at: ..STALE_AFTER.ago })
         .order(:id)
  end
end
