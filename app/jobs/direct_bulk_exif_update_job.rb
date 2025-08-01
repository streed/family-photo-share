require "mini_exiftool"
require "tempfile"

class DirectBulkExifUpdateJob
  include Sidekiq::Job

  sidekiq_options queue: "bulk_processing", retry: 3

  def perform(photo_ids = nil, options = {})
    # Options can include:
    # - only_missing_dates: true/false (only process photos without taken_at)
    # - batch_size: number of photos to process at once

    only_missing_dates = options["only_missing_dates"] || false
    batch_size = options["batch_size"] || 50

    # Build query
    photos = photo_ids ? Photo.where(id: photo_ids) : Photo.all
    photos = photos.where(taken_at: nil) if only_missing_dates

    total = photos.count
    processed = 0
    updated = 0
    failed = 0

    Rails.logger.info "Starting direct bulk EXIF update for #{total} photos"

    photos.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |photo|
        next unless photo.image.attached?

        begin
          if extract_metadata_for_photo(photo)
            updated += 1
          end
          processed += 1
        rescue => e
          failed += 1
          Rails.logger.error "Failed to extract EXIF for photo #{photo.id}: #{e.message}"
        end
      end

      # Log progress
      Rails.logger.info "Direct EXIF update progress: #{processed}/#{total} (#{updated} updated, #{failed} failed)"

      # Small delay to prevent overwhelming the system
      sleep(0.1)
    end

    Rails.logger.info "Direct bulk EXIF update completed! Total: #{total}, Processed: #{processed}, Updated: #{updated}, Failed: #{failed}"

    # Return summary
    {
      total: total,
      processed: processed,
      updated: updated,
      failed: failed,
      completed_at: Time.current
    }
  end

  private

  def extract_metadata_for_photo(photo)
    updated = false

    # Download image to temp file for EXIF extraction
    Tempfile.create([ "photo", File.extname(photo.image.filename.to_s) ]) do |tempfile|
      tempfile.binmode
      photo.image.download { |chunk| tempfile.write(chunk) }
      tempfile.rewind

      begin
        exif = MiniExiftool.new(tempfile.path)

        # Store all EXIF data in metadata field
        photo.metadata = exif.to_hash.transform_keys(&:to_s)

        # Extract date taken
        if photo.taken_at.nil? && extract_date_taken(photo, exif)
          updated = true
        end

        # Extract GPS coordinates
        if photo.latitude.nil? && extract_gps_coordinates(photo, exif)
          updated = true
        end

        # Extract camera information
        if photo.camera_make.nil? && extract_camera_info(photo, exif)
          updated = true
        end

        # Save without triggering callbacks
        photo.save!(validate: false) if updated || photo.metadata_changed?

      rescue MiniExiftool::Error => e
        Rails.logger.debug { "No EXIF data found for photo #{photo.id}: #{e.message}" }
      end
    end

    updated
  end

  def extract_date_taken(photo, exif)
    date_fields = [ :DateTimeOriginal, :CreateDate, :ModifyDate, :DateTime ]

    date_fields.each do |field|
      if exif[field].present?
        begin
          photo.taken_at = parse_exif_date(exif[field])
          return true
        rescue => e
          Rails.logger.debug { "Failed to parse date from #{field}: #{e.message}" }
        end
      end
    end

    false
  end

  def extract_gps_coordinates(photo, exif)
    if exif[:GPSLatitude].present? && exif[:GPSLongitude].present?
      begin
        lat = convert_to_decimal(exif[:GPSLatitude], exif[:GPSLatitudeRef])
        lng = convert_to_decimal(exif[:GPSLongitude], exif[:GPSLongitudeRef])

        if lat && lng
          photo.latitude = lat
          photo.longitude = lng
          return true
        end
      rescue => e
        Rails.logger.error "Failed to parse GPS coordinates: #{e.message}"
      end
    end

    false
  end

  def extract_camera_info(photo, exif)
    updated = false

    if exif[:Make].present?
      photo.camera_make = exif[:Make].to_s.strip
      updated = true
    end

    if exif[:Model].present?
      photo.camera_model = exif[:Model].to_s.strip
      updated = true
    end

    # Clean up camera info
    if photo.camera_make.present? && photo.camera_model.present?
      if photo.camera_model.start_with?(photo.camera_make)
        photo.camera_model = photo.camera_model.sub(photo.camera_make, "").strip
      end
    end

    updated
  end

  def parse_exif_date(date_value)
    return nil unless date_value
    return date_value if date_value.is_a?(Time)

    date_string = date_value.to_s

    # EXIF dates are typically in format: "2023:12:25 14:30:45"
    if date_string.match?(/^\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}/)
      formatted_date = date_string.sub(/^(\d{4}):(\d{2}):(\d{2})/, '\1-\2-\3')
      Time.zone.parse(formatted_date)
    else
      Time.zone.parse(date_string)
    end
  end

  def convert_to_decimal(coordinate, ref)
    return nil unless coordinate && ref

    if coordinate.is_a?(Array) && coordinate.length == 3
      degrees = coordinate[0].to_f
      minutes = coordinate[1].to_f
      seconds = coordinate[2].to_f
    elsif coordinate.is_a?(String)
      match = coordinate.match(/(\d+)\s*deg\s*(\d+)'\s*([\d.]+)"?/)
      return nil unless match
      degrees = match[1].to_f
      minutes = match[2].to_f
      seconds = match[3].to_f
    else
      return nil
    end

    decimal = degrees + (minutes / 60.0) + (seconds / 3600.0)

    if ref && (ref.upcase == "S" || ref.upcase == "W")
      decimal = -decimal
    end

    decimal.round(6)
  end
end
