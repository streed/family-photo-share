namespace :photos do
  desc "Update EXIF data for all photos in the database"
  task update_exif: :environment do
    puts "Starting bulk EXIF data update..."
    
    # Get count of photos
    total_photos = Photo.count
    puts "Found #{total_photos} photos to process"
    
    if total_photos == 0
      puts "No photos found in database"
      exit
    end
    
    # Process in batches to avoid memory issues
    batch_size = 100
    processed = 0
    failed = 0
    skipped = 0
    
    Photo.find_each(batch_size: batch_size) do |photo|
      # Skip if no image attached
      unless photo.image.attached?
        skipped += 1
        print "S"
        next
      end
      
      begin
        # Queue the job for EXIF extraction
        ExtractPhotoMetadataJob.perform_async(photo.id)
        processed += 1
        print "."
      rescue => e
        failed += 1
        print "F"
        Rails.logger.error "Failed to queue EXIF extraction for photo #{photo.id}: #{e.message}"
      end
      
      # Show progress every 10 photos
      if (processed + failed + skipped) % 10 == 0
        print " #{processed + failed + skipped}/#{total_photos}"
      end
    end
    
    puts "\n\nBulk EXIF update queued!"
    puts "Total photos: #{total_photos}"
    puts "Queued for processing: #{processed}"
    puts "Failed to queue: #{failed}"
    puts "Skipped (no image): #{skipped}"
    puts "\nJobs have been queued to Sidekiq. Check Sidekiq for processing status."
  end
  
  desc "Update EXIF data for photos missing taken_at date"
  task update_missing_exif: :environment do
    puts "Starting EXIF update for photos missing taken_at date..."
    
    # Get photos without taken_at
    photos_missing_date = Photo.where(taken_at: nil)
    total_photos = photos_missing_date.count
    puts "Found #{total_photos} photos missing taken_at date"
    
    if total_photos == 0
      puts "All photos have taken_at dates!"
      exit
    end
    
    processed = 0
    failed = 0
    skipped = 0
    
    photos_missing_date.find_each do |photo|
      # Skip if no image attached
      unless photo.image.attached?
        skipped += 1
        print "S"
        next
      end
      
      begin
        # Queue the job for EXIF extraction
        ExtractPhotoMetadataJob.perform_async(photo.id)
        processed += 1
        print "."
      rescue => e
        failed += 1
        print "F"
        Rails.logger.error "Failed to queue EXIF extraction for photo #{photo.id}: #{e.message}"
      end
      
      # Show progress every 10 photos
      if (processed + failed + skipped) % 10 == 0
        print " #{processed + failed + skipped}/#{total_photos}"
      end
    end
    
    puts "\n\nEXIF update queued for photos missing dates!"
    puts "Total photos missing dates: #{total_photos}"
    puts "Queued for processing: #{processed}"
    puts "Failed to queue: #{failed}"
    puts "Skipped (no image): #{skipped}"
    puts "\nJobs have been queued to Sidekiq. Check Sidekiq for processing status."
  end
  
  desc "Force update EXIF data for a specific photo"
  task :update_exif_for_photo, [:photo_id] => :environment do |task, args|
    photo_id = args[:photo_id]
    
    unless photo_id
      puts "Please provide a photo ID: rake photos:update_exif_for_photo[123]"
      exit
    end
    
    photo = Photo.find_by(id: photo_id)
    
    unless photo
      puts "Photo with ID #{photo_id} not found"
      exit
    end
    
    unless photo.image.attached?
      puts "Photo #{photo_id} has no image attached"
      exit
    end
    
    puts "Processing photo #{photo_id}..."
    puts "Title: #{photo.title || 'Untitled'}"
    puts "Current taken_at: #{photo.taken_at || 'Not set'}"
    puts "Current location: #{photo.latitude ? "#{photo.latitude}, #{photo.longitude}" : 'Not set'}"
    
    # Perform synchronously for immediate feedback
    ExtractPhotoMetadataJob.new.perform(photo_id)
    
    # Reload to show updated data
    photo.reload
    puts "\nAfter processing:"
    puts "taken_at: #{photo.taken_at || 'Not set'}"
    puts "location: #{photo.latitude ? "#{photo.latitude}, #{photo.longitude}" : 'Not set'}"
    puts "camera: #{photo.camera_make} #{photo.camera_model}".strip
    puts "metadata keys: #{photo.metadata.keys.join(', ')}" if photo.metadata.present?
  end
  
  desc "Show EXIF statistics for all photos"
  task exif_stats: :environment do
    total = Photo.count
    with_taken_at = Photo.where.not(taken_at: nil).count
    with_location = Photo.where.not(latitude: nil).count
    with_camera = Photo.where.not(camera_make: nil).count
    with_metadata = Photo.where("metadata != '{}'").count
    
    puts "Photo EXIF Statistics:"
    puts "====================="
    puts "Total photos: #{total}"
    puts "With taken_at date: #{with_taken_at} (#{(with_taken_at.to_f / total * 100).round(1)}%)"
    puts "With GPS location: #{with_location} (#{(with_location.to_f / total * 100).round(1)}%)"
    puts "With camera info: #{with_camera} (#{(with_camera.to_f / total * 100).round(1)}%)"
    puts "With any metadata: #{with_metadata} (#{(with_metadata.to_f / total * 100).round(1)}%)"
    
    # Show photos missing dates
    missing_date_count = total - with_taken_at
    if missing_date_count > 0
      puts "\nPhotos missing taken_at date: #{missing_date_count}"
      puts "Run 'rake photos:update_missing_exif' to process these photos"
    end
  end
  
  desc "Update EXIF data directly (without queueing individual jobs)"
  task update_exif_direct: :environment do
    puts "Starting direct bulk EXIF data update..."
    puts "This will process photos directly without creating individual Sidekiq jobs."
    
    total_photos = Photo.count
    puts "Found #{total_photos} photos to process"
    
    if total_photos == 0
      puts "No photos found in database"
      exit
    end
    
    # Queue the direct bulk job
    job_id = DirectBulkExifUpdateJob.perform_async
    
    puts "\nDirect bulk EXIF update job queued!"
    puts "Job ID: #{job_id}"
    puts "This job will process all photos in batches."
    puts "Check Sidekiq for processing status."
  end
  
  desc "Update EXIF data directly for photos missing taken_at"
  task update_missing_exif_direct: :environment do
    puts "Starting direct EXIF update for photos missing taken_at date..."
    
    missing_count = Photo.where(taken_at: nil).count
    puts "Found #{missing_count} photos missing taken_at date"
    
    if missing_count == 0
      puts "All photos have taken_at dates!"
      exit
    end
    
    # Queue the direct bulk job with only_missing_dates option
    job_id = DirectBulkExifUpdateJob.perform_async(nil, { 'only_missing_dates' => true })
    
    puts "\nDirect bulk EXIF update job queued!"
    puts "Job ID: #{job_id}"
    puts "This job will process only photos missing taken_at dates."
    puts "Check Sidekiq for processing status."
  end
end