class CleanupAlbumViewEventsJob < ApplicationJob
  queue_as :low

  def perform
    # Delete all AlbumViewEvent records older than 7 days
    cutoff_date = 7.days.ago
    
    deleted_count = AlbumViewEvent.where('occurred_at < ?', cutoff_date).delete_all
    
    Rails.logger.info "Deleted #{deleted_count} old album view events (older than #{cutoff_date})"
  end
end