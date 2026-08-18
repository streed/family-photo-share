# Resolves one IP address to a place and caches the answer.
#
# Runs in the background because it makes an HTTP call: a guest opening a shared
# album must never wait on a geolocation provider.
class ResolveIpLocationJob < ApplicationJob
  queue_as :default

  def perform(ip_address)
    return if ip_address.blank?

    record = IpLocation.find_or_initialize_by(ip_address: ip_address)

    # Another job may have resolved it between enqueue and run.
    return if record.persisted? && record.resolved? && record.fresh?

    result = IpGeolocationLookup.call(ip_address)

    record.assign_attributes(
      status: result.status,
      city: result.city,
      region: result.region,
      country: result.country,
      country_code: result.country_code,
      postal_code: result.postal_code,
      timezone: result.timezone,
      latitude: numeric(result.latitude),
      longitude: numeric(result.longitude),
      provider: result.provider,
      resolved_at: Time.current
    )

    record.save!
  rescue ActiveRecord::RecordNotUnique
    # Two jobs raced for the same new address; the other one won, which is fine.
    nil
  end

  private

  def numeric(value)
    return nil if value.blank?

    Float(value)
  rescue ArgumentError, TypeError
    nil
  end
end
