class BulkUploadProcessingJob
  include Sidekiq::Job

  def perform(bulk_upload_id)
    bulk_upload = BulkUpload.find(bulk_upload_id)
    bulk_upload.update!(status: BulkUpload::STATUSES[:processing])
    
    # Set initial counts
    total_count = bulk_upload.images.count
    bulk_upload.update!(total_count: total_count)
    
    processed_count = 0
    failed_count = 0
    
    begin
      bulk_upload.images.each_with_index do |image, index|
        begin
          # Create photo from the uploaded image
          photo = create_photo_from_image(bulk_upload, image, index)
          
          if photo.persisted?
            # Add to album if specified
            if bulk_upload.album.present?
              bulk_upload.album.add_photo(photo)
            end
            
            # Create the association
            bulk_upload.bulk_upload_photos.create!(photo: photo)
            processed_count += 1
          else
            failed_count += 1
            bulk_upload.add_error(image.filename.to_s, photo.errors.full_messages.join(', '))
          end
          
        rescue => e
          failed_count += 1
          bulk_upload.add_error(image.filename.to_s, e.message)
          Rails.logger.error "Failed to process image #{image.filename}: #{e.message}"
        end
        
        # Update progress
        bulk_upload.update!(
          processed_count: processed_count + failed_count,
          failed_count: failed_count
        )
      end
      
      # Determine final status
      final_status = if failed_count == 0
        BulkUpload::STATUSES[:completed]
      elsif processed_count == 0
        BulkUpload::STATUSES[:failed]
      else
        BulkUpload::STATUSES[:partial]
      end
      
      bulk_upload.update!(status: final_status)
      
    rescue => e
      bulk_upload.update!(
        status: BulkUpload::STATUSES[:failed],
        error_messages: "Processing failed: #{e.message}"
      )
      Rails.logger.error "Bulk upload processing failed: #{e.message}"
      raise e
    end
  end
  
  private
  
  def create_photo_from_image(bulk_upload, image, index)
    filename = image.filename.to_s
    
    # Get metadata for this specific photo
    metadata_array = bulk_upload.metadata.present? ? JSON.parse(bulk_upload.metadata) : []
    photo_metadata = metadata_array.find { |m| m['filename'] == filename } || {}
    
    # Use provided metadata or extract from filename
    title = photo_metadata['title'].presence || extract_title_from_filename(filename)
    description = photo_metadata['description'].presence
    
    photo = bulk_upload.user.photos.build(
      title: title,
      description: description,
      original_filename: filename,
      taken_at: extract_date_from_filename(filename) || Time.current
    )
    
    # Attach the image
    photo.image.attach(
      io: image.blob.open,
      filename: image.filename,
      content_type: image.blob.content_type
    )
    
    photo.save
    photo
  end
  
  def extract_date_from_filename(filename)
    # Try to extract date from common filename patterns
    # e.g., IMG_20231225_120000.jpg, 2023-12-25_12-00-00.jpg, etc.
    
    date_patterns = [
      /(\d{4})(\d{2})(\d{2})/,           # YYYYMMDD
      /(\d{4})-(\d{2})-(\d{2})/,        # YYYY-MM-DD
      /(\d{4})_(\d{2})_(\d{2})/,        # YYYY_MM_DD
      /(\d{2})(\d{2})(\d{4})/,          # MMDDYYYY
      /(\d{2})-(\d{2})-(\d{4})/         # MM-DD-YYYY
    ]
    
    date_patterns.each do |pattern|
      match = filename.match(pattern)
      if match
        begin
          if match[1].length == 4 # Year first
            year, month, day = match[1].to_i, match[2].to_i, match[3].to_i
          else # Year last
            month, day, year = match[1].to_i, match[2].to_i, match[3].to_i
          end
          
          return Date.new(year, month, day) if Date.valid_date?(year, month, day)
        rescue
          # Invalid date, continue to next pattern
        end
      end
    end
    
    nil
  end
  
  def extract_title_from_filename(filename)
    # Remove extension and replace underscores/dashes with spaces
    name_without_ext = File.basename(filename, File.extname(filename))
    return nil if name_without_ext.blank?
    
    name_without_ext
      .gsub(/[_-]/, ' ')
      .gsub(/\b\w/) { |match| match.upcase }
      .strip
  end
end