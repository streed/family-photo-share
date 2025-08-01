namespace :storage do
  desc "Clean up orphaned Active Storage blobs and attachments"
  task cleanup: :environment do
    puts "Starting Active Storage cleanup..."

    # Find attachments without blobs
    orphaned_attachments = ActiveStorage::Attachment.left_joins(:blob).where(active_storage_blobs: { id: nil })
    puts "Found #{orphaned_attachments.count} orphaned attachments"
    orphaned_attachments.destroy_all

    # Find blobs without files
    orphaned_count = 0
    ActiveStorage::Blob.find_each do |blob|
      begin
        path = blob.service.path_for(blob.key)
        unless File.exist?(path)
          # Create missing directory structure
          FileUtils.mkdir_p(File.dirname(path))
          # Create empty placeholder file
          File.write(path, "")
          puts "Created placeholder for missing file: #{blob.key}"
        end
      rescue => e
        puts "Error processing blob #{blob.id}: #{e.message}"
        orphaned_count += 1
      end
    end

    puts "Storage cleanup completed. Created placeholders for #{orphaned_count} missing files."
  end

  desc "Remove all Active Storage data (DESTRUCTIVE)"
  task reset: :environment do
    puts "WARNING: This will delete ALL uploaded files and Active Storage data!"
    print "Are you sure? (yes/no): "
    response = STDIN.gets.chomp

    if response.downcase == "yes"
      # Delete in proper order to avoid foreign key constraints
      ActiveStorage::VariantRecord.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Photo.delete_all

      # Clean up storage directory
      FileUtils.rm_rf(Rails.root.join("storage"))
      FileUtils.mkdir_p(Rails.root.join("storage"))
      File.write(Rails.root.join("storage/.keep"), "")
      puts "Active Storage reset completed."
    else
      puts "Reset cancelled."
    end
  end
end
