class CleanupShortUrlsJob < ApplicationJob
  queue_as :low

  # short_urls rows are minted per photo per variant and expire after 7 days.
  # ShortUrl.cleanup_expired! existed but was never scheduled, so the table only
  # ever grew — every expired row stayed behind forever.
  def perform
    expired_count = ShortUrl.expired.count
    ShortUrl.cleanup_expired!

    Rails.logger.info "Cleaned up #{expired_count} expired short URLs"

    {
      expired_short_urls_removed: expired_count,
      remaining: ShortUrl.count,
      cleaned_at: Time.current
    }
  end
end
