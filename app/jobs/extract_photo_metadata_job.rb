require 'mini_exiftool'
require 'tempfile'

class ExtractPhotoMetadataJob
  include Sidekiq::Job
  
  sidekiq_options queue: 'image_processing', retry: 3

  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    return unless photo
    return unless photo.image.attached?
    
    Rails.logger.info "Extracting metadata for photo #{photo_id}"
    
    # Download image to temp file for EXIF extraction
    Tempfile.create(['photo', File.extname(photo.image.filename.to_s)]) do |tempfile|
      tempfile.binmode
      photo.image.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind
      
      # Extract EXIF data using mini_exiftool
      begin
        exif = MiniExiftool.new(tempfile.path)
        
        # Store all EXIF data in metadata field
        photo.metadata = exif.to_hash.transform_keys(&:to_s)
        
        # Extract date taken
        extract_date_taken(photo, exif)
        
        # Extract GPS coordinates
        extract_gps_coordinates(photo, exif)
        
        # Extract camera information
        extract_camera_info(photo, exif)
        
        # Save without triggering callbacks to avoid infinite loop
        photo.save!(validate: false)
        
        Rails.logger.info "Successfully extracted metadata for photo #{photo_id}"
      rescue MiniExiftool::Error => e
        Rails.logger.warn "No EXIF data found for photo #{photo_id}: #{e.message}"
        # Still save the photo even if no EXIF data
        photo.save!(validate: false)
      end
    end
  rescue => e
    Rails.logger.error "Error extracting metadata for photo #{photo_id}: #{e.message}"
    raise # Re-raise to trigger Sidekiq retry
  end
  
  private
  
  def extract_date_taken(photo, exif)
    # Try different EXIF date fields in order of preference
    date_fields = [
      :DateTimeOriginal,
      :CreateDate,
      :ModifyDate,
      :DateTime
    ]
    
    date_fields.each do |field|
      if exif[field].present?
        begin
          photo.taken_at = parse_exif_date(exif[field])
          Rails.logger.info "Extracted date from #{field}: #{photo.taken_at}"
          break
        rescue => e
          Rails.logger.warn "Failed to parse date from #{field}: #{e.message}"
        end
      end
    end
  end
  
  def extract_gps_coordinates(photo, exif)
    # Extract GPS coordinates if available
    if exif[:GPSLatitude].present? && exif[:GPSLongitude].present?
      begin
        # Convert GPS coordinates to decimal
        lat = convert_to_decimal(exif[:GPSLatitude], exif[:GPSLatitudeRef])
        lng = convert_to_decimal(exif[:GPSLongitude], exif[:GPSLongitudeRef])
        
        if lat && lng
          photo.latitude = lat
          photo.longitude = lng
          Rails.logger.info "Extracted GPS coordinates: #{lat}, #{lng}"
        end
      rescue => e
        Rails.logger.error "Failed to parse GPS coordinates: #{e.message}"
      end
    end
  end
  
  def extract_camera_info(photo, exif)
    # Extract camera make and model
    photo.camera_make = exif[:Make].to_s.strip if exif[:Make].present?
    photo.camera_model = exif[:Model].to_s.strip if exif[:Model].present?
    
    # Clean up camera info (remove trailing spaces and manufacturer duplication)
    if photo.camera_make.present? && photo.camera_model.present?
      # Remove make from model if it's duplicated
      if photo.camera_model.start_with?(photo.camera_make)
        photo.camera_model = photo.camera_model.sub(photo.camera_make, '').strip
      end
    end
  end
  
  def parse_exif_date(date_value)
    return nil unless date_value
    
    # Handle Time objects directly
    return date_value if date_value.is_a?(Time)
    
    date_string = date_value.to_s
    
    # EXIF dates are typically in format: "2023:12:25 14:30:45"
    if date_string.match?(/^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}/)
      # Replace first two colons with dashes for proper parsing
      formatted_date = date_string.sub(/^(\d{4}):(\d{2}):(\d{2})/, '\1-\2-\3')
      Time.zone.parse(formatted_date)
    else
      Time.zone.parse(date_string)
    end
  end
  
  def convert_to_decimal(coordinate, ref)
    return nil unless coordinate && ref
    
    # Handle different formats of GPS coordinates
    if coordinate.is_a?(Array) && coordinate.length == 3
      # Format: [degrees, minutes, seconds]
      degrees = coordinate[0].to_f
      minutes = coordinate[1].to_f
      seconds = coordinate[2].to_f
    elsif coordinate.is_a?(String)
      # Parse string format like "40 deg 26' 46.30\" N"
      match = coordinate.match(/(\d+)\s*deg\s*(\d+)'\s*([\d.]+)"?/)
      return nil unless match
      degrees = match[1].to_f
      minutes = match[2].to_f
      seconds = match[3].to_f
    else
      return nil
    end
    
    # Convert to decimal
    decimal = degrees + (minutes / 60.0) + (seconds / 3600.0)
    
    # Apply direction (S and W are negative)
    if ref && (ref.upcase == 'S' || ref.upcase == 'W')
      decimal = -decimal
    end
    
    decimal.round(6)
  end
end