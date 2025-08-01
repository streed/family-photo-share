class BulkExifUpdateJob
  include Sidekiq::Job

  sidekiq_options queue: "bulk_processing", retry: 3

  def perform(photo_ids = nil)
    # If no specific IDs provided, process all photos
    photos = photo_ids ? Photo.where(id: photo_ids) : Photo.all

    total = photos.count
    processed = 0
    failed = 0

    Rails.logger.info "Starting bulk EXIF update for #{total} photos"

    photos.find_each do |photo|
      next unless photo.image.attached?

      begin
        # Queue individual job for each photo
        ExtractPhotoMetadataJob.perform_async(photo.id)
        processed += 1
      rescue => e
        failed += 1
        Rails.logger.error "Failed to queue EXIF extraction for photo #{photo.id}: #{e.message}"
      end

      # Log progress every 100 photos
      if (processed + failed) % 100 == 0
        Rails.logger.info "Bulk EXIF update progress: #{processed + failed}/#{total} (#{failed} failed)"
      end
    end

    Rails.logger.info "Bulk EXIF update completed! Processed: #{processed}, Failed: #{failed}, Total: #{total}"

    # Return summary
    {
      total: total,
      processed: processed,
      failed: failed,
      completed_at: Time.current
    }
  end
end
