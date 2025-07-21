namespace :short_urls do
  desc "Clean up expired short URLs"
  task cleanup: :environment do
    puts "Cleaning up expired short URLs..."
    
    count = ShortUrl.expired.count
    ShortUrl.cleanup_expired!
    
    puts "Deleted #{count} expired short URLs"
  end
  
  desc "Show short URL statistics"
  task stats: :environment do
    total = ShortUrl.count
    active = ShortUrl.active.count
    expired = ShortUrl.expired.count
    
    puts "Short URL Statistics"
    puts "==================="
    puts "Total URLs:   #{total}"
    puts "Active URLs:  #{active}"
    puts "Expired URLs: #{expired}"
    puts ""
    
    if total > 0
      # Show top accessed URLs
      puts "Top 10 Most Accessed URLs:"
      ShortUrl.active.order(access_count: :desc).limit(10).each_with_index do |url, index|
        puts "  #{index + 1}. #{url.token} - #{url.access_count} accesses (#{url.resource_type} #{url.resource_id})"
      end
    end
  end
  
  desc "Generate short URLs for all existing photos"
  task generate_for_photos: :environment do
    puts "Generating short URLs for all photos..."
    
    Photo.includes(:image_attachment).find_each do |photo|
      next unless photo.image.attached?
      
      # Generate for all variants
      %w[thumbnail medium large original].each do |variant|
        ShortUrl.for_photo_variant(photo, variant)
      end
      
      print "."
    end
    
    puts "\nCompleted generating short URLs for all photos"
  end
end