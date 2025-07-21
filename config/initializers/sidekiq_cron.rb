if defined?(Sidekiq)
  require 'sidekiq/cron/job'

  Sidekiq.configure_server do |config|
    # Load cron jobs only in the server (worker) process
    schedule_file = Rails.root.join('config', 'sidekiq_cron_schedule.yml')

    if File.exist?(schedule_file)
      schedule = YAML.load_file(schedule_file)
      
      Sidekiq::Cron::Job.load_from_hash!(schedule)
      
      Rails.logger.info "Loaded #{schedule.size} cron jobs from sidekiq_cron_schedule.yml"
    else
      # Define jobs directly if no YAML file exists
      jobs = [
        {
          'name' => 'cleanup_expired_sessions',
          'class' => 'CleanupExpiredSessionsJob',
          'cron' => '0 * * * *', # Every hour
          'queue' => 'default',
          'description' => 'Clean up expired guest access sessions'
        }
      ]
      
      jobs.each do |job_hash|
        Sidekiq::Cron::Job.create(job_hash)
      end
      
      Rails.logger.info "Created #{jobs.size} cron jobs programmatically"
    end
  end
end