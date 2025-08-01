class CleanupExpiredSessionsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting cleanup of expired guest sessions..."

    # Clean up expired album access sessions
    expired_count = AlbumAccessSession.expired.count
    AlbumAccessSession.cleanup_expired

    Rails.logger.info "Cleaned up #{expired_count} expired guest sessions"

    # Also clean up any orphaned sessions (where the album no longer exists)
    orphaned_sessions = AlbumAccessSession.where.missing(:album)
    orphaned_count = orphaned_sessions.count
    orphaned_sessions.destroy_all

    Rails.logger.info "Cleaned up #{orphaned_count} orphaned guest sessions"

    # Log statistics about remaining active sessions
    active_sessions = AlbumAccessSession.active.count
    Rails.logger.info "#{active_sessions} active guest sessions remaining"

    # Return summary for monitoring
    {
      expired_sessions_removed: expired_count,
      orphaned_sessions_removed: orphaned_count,
      active_sessions_remaining: active_sessions,
      cleaned_at: Time.current
    }
  end
end
