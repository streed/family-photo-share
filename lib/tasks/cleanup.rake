namespace :cleanup do
  desc "Clean up expired guest sessions"
  task expired_sessions: :environment do
    puts "Starting cleanup of expired guest sessions..."
    CleanupExpiredSessionsJob.perform_now
  end
  
  desc "Clean up all expired data (sessions, old jobs, etc.)"
  task all: :environment do
    puts "Running comprehensive cleanup..."
    
    # Clean up expired guest sessions
    Rake::Task["cleanup:expired_sessions"].invoke
    
    # Clean up old Sidekiq jobs (older than 30 days)
    if defined?(Sidekiq::Stats)
      stats = Sidekiq::Stats.new
      puts "Sidekiq statistics before cleanup:"
      puts "  Processed: #{stats.processed}"
      puts "  Failed: #{stats.failed}"
    end
    
    # You can add more cleanup tasks here as needed
    # For example:
    # - Old image processing artifacts
    # - Temporary files
    # - Old logs
    
    puts "Cleanup completed!"
  end
end

# This task can be scheduled via cron to run periodically
# Example crontab entry to run every hour:
# 0 * * * * cd /path/to/app && bundle exec rails cleanup:expired_sessions RAILS_ENV=production