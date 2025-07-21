class ExtractPhotoMetadataJob
  include Sidekiq::Job
  
  sidekiq_options queue: 'image_processing', retry: 3

  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    return unless photo
    return unless photo.image.attached?
    
    Rails.logger.info "Extracting metadata for photo #{photo_id}"
    
    # Ensure the blob is analyzed first
    photo.image.blob.analyze unless photo.image.blob.analyzed?
    
    # Extract metadata
    metadata = photo.image.blob.metadata
    
    # Update photo with extracted metadata
    photo.metadata = metadata
    
    # Extract date taken from EXIF data if available
    if metadata['date_time_original'].present?
      begin
        date_taken = parse_exif_date(metadata['date_time_original'])
        photo.taken_at = date_taken if date_taken
      rescue => e
        Rails.logger.error "Failed to parse EXIF date for photo #{photo_id}: #{e.message}"
      end
    elsif metadata['date_time'].present?
      # Fallback to date_time if date_time_original is not available
      begin
        date_taken = parse_exif_date(metadata['date_time'])
        photo.taken_at = date_taken if date_taken
      rescue => e
        Rails.logger.error "Failed to parse EXIF date for photo #{photo_id}: #{e.message}"
      end
    end
    
    # Extract GPS coordinates if available
    if metadata['gps_latitude'].present? && metadata['gps_longitude'].present?
      photo.latitude = metadata['gps_latitude']
      photo.longitude = metadata['gps_longitude']
    end
    
    # Extract camera information
    photo.camera_make = metadata['make'] if metadata['make'].present?
    photo.camera_model = metadata['model'] if metadata['model'].present?
    
    # Save without triggering callbacks to avoid infinite loop
    photo.save!(validate: false)
    
    Rails.logger.info "Successfully extracted metadata for photo #{photo_id}"
  rescue => e
    Rails.logger.error "Error extracting metadata for photo #{photo_id}: #{e.message}"
    raise # Re-raise to trigger Sidekiq retry
  end
  
  private
  
  def parse_exif_date(date_string)
    # EXIF dates are typically in format: "2023:12:25 14:30:45"
    if date_string.match?(/^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}$/)
      Time.zone.parse(date_string.gsub(':', '-', 2))
    else
      Time.zone.parse(date_string)
    end
  end
end