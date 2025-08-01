namespace :images do
  desc "Process all unprocessed images"
  task process_all: :environment do
    puts "Starting bulk image processing..."

    total_count = Photo.joins(:image_attachment).where(processing_completed_at: nil).count

    if total_count.zero?
      puts "No unprocessed images found."
      exit 0
    end

    puts "Found #{total_count} unprocessed images"
    puts "Starting background processing..."

    BulkImageProcessingJob.perform_async(10)

    puts "Bulk processing job queued. Check Sidekiq for progress."
    puts "You can monitor progress with: rails images:status"
  end

  desc "Show processing status"
  task status: :environment do
    total_photos = Photo.joins(:image_attachment).count
    processed_photos = Photo.joins(:image_attachment).where.not(processing_completed_at: nil).count
    unprocessed_photos = total_photos - processed_photos

    puts "Image Processing Status:"
    puts "=" * 30
    puts "Total photos: #{total_photos}"
    puts "Processed: #{processed_photos}"
    puts "Unprocessed: #{unprocessed_photos}"
    puts "Progress: #{((processed_photos.to_f / total_photos) * 100).round(1)}%" if total_photos > 0

    if unprocessed_photos > 0
      puts "\nTo process remaining images, run:"
      puts "rails images:process_all"
    else
      puts "\nAll images have been processed!"
    end
  end

  desc "Reprocess specific photo by ID"
  task :reprocess, [ :photo_id ] => :environment do |t, args|
    photo_id = args[:photo_id]

    if photo_id.blank?
      puts "Usage: rails images:reprocess[photo_id]"
      exit 1
    end

    photo = Photo.find(photo_id)
    puts "Reprocessing Photo #{photo.id}: #{photo.title}"

    # Reset processing status
    photo.update_column(:processing_completed_at, nil)

    # Queue for processing
    ImageProcessingJob.perform_async(photo.id)

    puts "Photo queued for reprocessing"
  rescue ActiveRecord::RecordNotFound
    puts "Photo with ID #{photo_id} not found"
    exit 1
  end

  desc "Clean up failed processing jobs"
  task cleanup: :environment do
    puts "Cleaning up stale processing records..."

    # Find photos marked as processing but haven't been updated in over 1 hour
    stale_photos = Photo.joins(:image_attachment)
                        .where(processing_completed_at: nil)
                        .where("updated_at < ?", 1.hour.ago)

    puts "Found #{stale_photos.count} stale processing records"

    stale_photos.find_each do |photo|
      puts "Re-queuing Photo #{photo.id}"
      ImageProcessingJob.perform_async(photo.id)
    end

    puts "Cleanup completed"
  end
end
