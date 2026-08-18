# Where an IP address is, as best as an IP can tell you.
#
# Guest activity records an IP for every view and every session, but an address
# on its own tells the album's owner nothing. This resolves one to a city and
# country and caches the answer, so a page listing 100 events makes zero network
# calls and repeated visits from the same address cost nothing.
#
# Accuracy is city-level at best, and only that for residential connections —
# mobile networks and VPNs routinely land in the wrong city, sometimes the wrong
# country. Nothing here asks the visitor for GPS permission, so this is the
# ceiling; the UI says "approximate" for that reason.
class IpLocation < ApplicationRecord
  STATUSES = %w[pending ok failed private].freeze

  # How long a resolved answer is trusted before it's looked up again. IP
  # allocations move, but slowly.
  TTL = 30.days

  validates :ip_address, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :resolved, -> { where(status: "ok") }
  scope :stale, -> { where(resolved_at: ..TTL.ago) }

  # The cached record for an address, or nil. Never triggers a lookup — callers
  # that want one enqueue ResolveIpLocationJob.
  def self.for_ip(ip)
    return nil if ip.blank?

    where(ip_address: ip.to_s).first
  end

  # Cached locations for a set of addresses, keyed by address, for list views.
  def self.lookup_map(ips)
    addresses = Array(ips).compact_blank.map(&:to_s).uniq
    return {} if addresses.empty?

    where(ip_address: addresses).index_by(&:ip_address)
  end

  # Kick off a lookup for an address unless one is already cached and fresh.
  #
  # Addresses on a local network can be settled here and now — they have no
  # public location, so there is nothing to ask a provider about, and leaving
  # them queued would show "looking up…" forever.
  def self.resolve_later(ip)
    return if ip.blank?

    record = for_ip(ip)
    return if record && record.status != "failed" && record.fresh?

    if IpGeolocationLookup.private_address?(ip)
      record ||= new(ip_address: ip.to_s)
      record.update!(status: "private", resolved_at: Time.current)
      return
    end

    ResolveIpLocationJob.perform_later(ip.to_s)
  rescue StandardError => e
    # Tracking a viewer's city is never worth failing their page view over.
    Rails.logger.warn "Could not enqueue IP lookup for #{ip}: #{e.class}: #{e.message}"
  end

  def fresh?
    resolved_at.present? && resolved_at > TTL.ago
  end

  def resolved?
    status == "ok"
  end

  # "Portland, Oregon, United States" — the most specific thing known, and
  # nothing invented when the lookup came back empty.
  def label
    return "Local network" if status == "private"
    return nil unless resolved?

    [ city.presence, region.presence, country.presence ].compact.uniq.join(", ").presence
  end

  def short_label
    return "Local network" if status == "private"
    return nil unless resolved?

    [ city.presence, (country_code.presence || country.presence) ].compact.join(", ").presence
  end

  def map_url
    return nil unless latitude.present? && longitude.present?

    "https://www.openstreetmap.org/?mlat=#{latitude}&mlon=#{longitude}#map=10/#{latitude}/#{longitude}"
  end
end
