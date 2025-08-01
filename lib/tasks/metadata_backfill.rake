namespace :photos do
  desc "Backfill metadata for existing photos"
  task backfill_metadata: :environment do
    puts "Starting metadata backfill for all photos..."
    puts "This will queue background jobs to extract EXIF data from photos."
    puts ""

    # Check current status
    progress = BulkMetadataBackfillJob.check_progress
    puts "Current status:"
    puts "  Total photos: #{progress[:total_photos]}"
    puts "  Photos with metadata: #{progress[:photos_with_metadata]}"
    puts "  Photos with taken_at date: #{progress[:photos_with_taken_at]}"
    puts "  Photos with GPS data: #{progress[:photos_with_gps]}"
    puts "  Photos with camera info: #{progress[:photos_with_camera_info]}"
    puts "  Completion: #{progress[:percentage_complete]}%"
    puts ""

    # Ask for confirmation
    print "Do you want to proceed? (y/N): "
    response = STDIN.gets.chomp.downcase

    unless response == "y"
      puts "Aborted."
      exit
    end

    # Run the backfill
    puts "Queueing metadata extraction jobs..."
    job_id = BulkMetadataBackfillJob.perform_async

    puts "Bulk backfill job queued with ID: #{job_id}"
    puts "Monitor progress in Sidekiq dashboard or by running:"
    puts "  rails photos:check_metadata_progress"
  end

  desc "Backfill metadata for photos in a date range"
  task :backfill_metadata_range, [ :start_date, :end_date ] => :environment do |t, args|
    unless args[:start_date] && args[:end_date]
      puts "Usage: rails photos:backfill_metadata_range[start_date,end_date]"
      puts "Example: rails photos:backfill_metadata_range[2024-01-01,2024-12-31]"
      exit
    end

    start_date = Date.parse(args[:start_date])
    end_date = Date.parse(args[:end_date])

    puts "Backfilling metadata for photos created between #{start_date} and #{end_date}"

    job = BulkMetadataBackfillJob.new
    count = job.perform_for_date_range(start_date, end_date)

    puts "Queued #{count} photos for metadata extraction"
  end

  desc "Check metadata backfill progress"
  task check_metadata_progress: :environment do
    progress = BulkMetadataBackfillJob.check_progress

    puts "Metadata Extraction Progress"
    puts "============================"
    puts "Total photos:           #{progress[:total_photos]}"
    puts "With metadata:          #{progress[:photos_with_metadata]} (#{progress[:percentage_complete]}%)"
    puts "With taken_at date:     #{progress[:photos_with_taken_at]}"
    puts "With GPS coordinates:   #{progress[:photos_with_gps]}"
    puts "With camera info:       #{progress[:photos_with_camera_info]}"
    puts ""

    # Show some examples
    if progress[:photos_with_taken_at] > 0
      puts "Sample photos with extracted dates:"
      Photo.where.not(taken_at: nil).limit(3).each do |photo|
        puts "  - #{photo.title}: taken at #{photo.taken_at}"
      end
    end

    if progress[:photos_with_gps] > 0
      puts "\nSample photos with GPS data:"
      Photo.where.not(latitude: nil).limit(3).each do |photo|
        puts "  - #{photo.title}: #{photo.latitude}, #{photo.longitude}"
      end
    end
  end

  desc "Force re-extract metadata for all photos (overwrites existing)"
  task force_metadata_extraction: :environment do
    puts "WARNING: This will re-extract metadata for ALL photos, overwriting existing data."
    print "Are you sure? (y/N): "
    response = STDIN.gets.chomp.downcase

    unless response == "y"
      puts "Aborted."
      exit
    end

    puts "Queueing metadata extraction for all photos..."
    job_id = BulkMetadataBackfillJob.perform_async(100, false)

    puts "Force extraction job queued with ID: #{job_id}"
  end
end
