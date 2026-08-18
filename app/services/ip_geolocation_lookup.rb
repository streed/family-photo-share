require "ipaddr"
require "net/http"
require "json"

# Turns an IP address into a place, using a keyless HTTPS geolocation service.
#
# Providers, in the order they're tried:
#
#   ipwho.is   — no key, HTTPS, city-level, generous free tier (the default)
#   ipapi.co   — no key, HTTPS, city-level, used when ipwho.is fails
#   ipinfo.io  — set IPINFO_TOKEN to use it first; the most accurate of the three
#
# Override the order with IP_GEOLOCATION_PROVIDERS ("ipinfo,ipwho,ipapi").
# Every provider is best-effort: a failed lookup records "failed" and the album
# owner sees the raw IP, which is what they saw before this existed.
class IpGeolocationLookup
  TIMEOUT = 3 # seconds, per provider — this runs in a background job

  Result = Struct.new(
    :status, :city, :region, :country, :country_code,
    :postal_code, :timezone, :latitude, :longitude, :provider,
    keyword_init: true
  )

  def self.call(ip)
    new(ip).call
  end

  # Loopback, LAN and link-local addresses have no public location, so there is
  # nothing worth asking a provider about.
  def self.private_address?(ip)
    new(ip).private_address?
  end

  def initialize(ip)
    @ip = ip.to_s.strip
  end

  def call
    return Result.new(status: "failed") if @ip.blank?
    return Result.new(status: "private") if private_address?

    providers.each do |provider|
      result = fetch_from(provider)
      return result if result&.status == "ok"
    end

    Result.new(status: "failed")
  end

  # Loopback, LAN and link-local addresses have no public location — and asking
  # a provider about them wastes a call and returns nonsense.
  def private_address?
    address = IPAddr.new(ip)
    address.loopback? || address.private? || address.link_local?
  rescue IPAddr::InvalidAddressError
    false
  end

  private

  attr_reader :ip

  def providers
    configured = ENV["IP_GEOLOCATION_PROVIDERS"].to_s.split(",").map(&:strip).reject(&:empty?)
    return configured if configured.any?

    ENV["IPINFO_TOKEN"].present? ? %w[ipinfo ipwho ipapi] : %w[ipwho ipapi]
  end

  def fetch_from(provider)
    case provider
    when "ipwho"  then parse_ipwho(get(URI("https://ipwho.is/#{ip}")))
    when "ipapi"  then parse_ipapi(get(URI("https://ipapi.co/#{ip}/json/")))
    when "ipinfo" then parse_ipinfo(get(ipinfo_uri))
    end
  rescue StandardError => e
    Rails.logger.info "IP lookup via #{provider} failed for #{ip}: #{e.class}: #{e.message}"
    nil
  end

  def ipinfo_uri
    uri = URI("https://ipinfo.io/#{ip}/json")
    uri.query = URI.encode_www_form(token: ENV["IPINFO_TOKEN"]) if ENV["IPINFO_TOKEN"].present?
    uri
  end

  def get(uri)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(uri.request_uri, "Accept" => "application/json", "User-Agent" => "FamilyPhotoShare/1.0")
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def parse_ipwho(body)
    return nil unless body.is_a?(Hash) && body["success"]

    Result.new(
      status: "ok",
      city: body["city"],
      region: body["region"],
      country: body["country"],
      country_code: body["country_code"],
      postal_code: body["postal"],
      timezone: body.dig("timezone", "id"),
      latitude: body["latitude"],
      longitude: body["longitude"],
      provider: "ipwho.is"
    )
  end

  def parse_ipapi(body)
    return nil unless body.is_a?(Hash) && body["error"].blank? && body["city"].present?

    Result.new(
      status: "ok",
      city: body["city"],
      region: body["region"],
      country: body["country_name"],
      country_code: body["country_code"],
      postal_code: body["postal"],
      timezone: body["timezone"],
      latitude: body["latitude"],
      longitude: body["longitude"],
      provider: "ipapi.co"
    )
  end

  def parse_ipinfo(body)
    return nil unless body.is_a?(Hash) && body["city"].present?

    latitude, longitude = body["loc"].to_s.split(",")

    Result.new(
      status: "ok",
      city: body["city"],
      region: body["region"],
      country: body["country"],          # ipinfo returns the two-letter code here
      country_code: body["country"],
      postal_code: body["postal"],
      timezone: body["timezone"],
      latitude: latitude,
      longitude: longitude,
      provider: "ipinfo.io"
    )
  end
end
