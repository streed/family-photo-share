class BulkMetadataBackfillJob
  include Sidekiq::Job
  
  sidekiq_options queue: 'bulk_processing', retry: 3

  def perform(batch_size = 100, only_missing = true)
    Rails.logger.info "Starting bulk metadata backfill with batch_size: #{batch_size}, only_missing: #{only_missing}"
    
    total_processed = 0
    total_updated = 0
    errors = []
    
    # Build the query based on parameters
    scope = Photo.includes(:image_attachment)
    
    if only_missing
      # Only process photos that haven't had metadata extracted yet
      scope = scope.where("taken_at IS NULL OR metadata IS NULL OR metadata::text = '{}'")
    end
    
    # Process in batches to avoid memory issues
    scope.find_in_batches(batch_size: batch_size) do |photos|
      photos.each do |photo|
        begin
          # Skip if no image attached
          unless photo.image.attached?
            Rails.logger.debug "Skipping photo #{photo.id} - no image attached"
            next
          end
          
          # Skip if already has comprehensive metadata (unless forced)
          if only_missing && photo.taken_at.present? && photo.metadata.present? && photo.metadata.keys.size > 3
            Rails.logger.debug "Skipping photo #{photo.id} - already has metadata"
            next
          end
          
          # Queue individual extraction job
          ExtractPhotoMetadataJob.perform_async(photo.id)
          total_processed += 1
          
          # Rate limiting to avoid overwhelming the queue
          sleep(0.1) if total_processed % 10 == 0
          
        rescue => e
          error_msg = "Error processing photo #{photo.id}: #{e.message}"
          Rails.logger.error error_msg
          errors << error_msg
        end
      end
      
      Rails.logger.info "Processed batch: #{total_processed} photos queued so far"
    end
    
    # Log summary
    summary = {
      total_photos_queued: total_processed,
      errors: errors,
      completed_at: Time.current
    }
    
    Rails.logger.info "Bulk metadata backfill completed: #{summary.to_json}"
    
    # Return summary for monitoring
    summary
  end
  
  # Alternative method to process photos within a date range
  def perform_for_date_range(start_date, end_date, batch_size = 100)
    Rails.logger.info "Starting bulk metadata backfill for photos created between #{start_date} and #{end_date}"
    
    total_processed = 0
    
    Photo.includes(:image_attachment)
         .where(created_at: start_date..end_date)
         .find_in_batches(batch_size: batch_size) do |photos|
      
      photos.each do |photo|
        next unless photo.image.attached?
        
        ExtractPhotoMetadataJob.perform_async(photo.id)
        total_processed += 1
      end
    end
    
    Rails.logger.info "Queued #{total_processed} photos for metadata extraction"
    total_processed
  end
  
  # Method to check backfill progress
  def self.check_progress
    total_photos = Photo.count
    # Use JSON query for PostgreSQL
    photos_with_metadata = Photo.where("metadata IS NOT NULL AND metadata::text != '{}'").count
    photos_with_taken_at = Photo.where.not(taken_at: nil).count
    photos_with_gps = Photo.where.not(latitude: nil, longitude: nil).count
    photos_with_camera = Photo.where.not(camera_make: nil).count
    
    {
      total_photos: total_photos,
      photos_with_metadata: photos_with_metadata,
      photos_with_taken_at: photos_with_taken_at,
      photos_with_gps: photos_with_gps,
      photos_with_camera_info: photos_with_camera,
      percentage_complete: total_photos > 0 ? (photos_with_metadata.to_f / total_photos * 100).round(2) : 0
    }
  end
end