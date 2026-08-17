class ShortUrl < ApplicationRecord
  validates :token, presence: true, uniqueness: true
  validates :resource_type, presence: true
  validates :resource_id, presence: true
  validates :expires_at, presence: true

  # Scopes
  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :for_resource, ->(resource_type, resource_id) { where(resource_type: resource_type, resource_id: resource_id) }

  # Generate a short token
  before_validation :generate_token, on: :create
  before_validation :set_default_expiry, on: :create

  TOKEN_BYTES = 8

  # Find or create a short URL for a resource
  def self.for_photo_variant(photo, variant_name)
    if (cached = photo.cached_short_url(variant_name))
      return cached
    end

    existing = active.for_resource("Photo", photo.id).find_by(variant: variant_name.to_s)
    return photo.cache_short_url(variant_name, existing) if existing

    created = create!(
      resource_type: "Photo",
      resource_id: photo.id,
      variant: variant_name.to_s
    )
    photo.cache_short_url(variant_name, created)
  end

  # Resolves every (photo, variant) pair a page is about to render in two
  # queries, then stashes the results on the photo objects themselves.
  #
  # Rendering a 30-photo album previously issued ~280 short_urls queries — one
  # SELECT per photo per variant, an INSERT whenever a row was missing or had
  # aged out, and two more queries per INSERT for the token uniqueness loop.
  # Because a read could write, the table also grew on every page view.
  def self.warm_for_photos(photos, variants)
    photos = Array(photos).reject { |p| p.nil? || p.id.nil? }
    variants = Array(variants).map(&:to_s)
    return if photos.empty? || variants.empty?

    photo_ids = photos.map(&:id).uniq

    existing = active.where(resource_type: "Photo", resource_id: photo_ids, variant: variants)
                     .index_by { |su| [ su.resource_id, su.variant ] }

    missing = []
    photo_ids.product(variants).each do |photo_id, variant|
      next if existing.key?([ photo_id, variant ])
      missing << { resource_id: photo_id, variant: variant }
    end

    existing.merge!(bulk_create(missing).index_by { |su| [ su.resource_id, su.variant ] }) if missing.any?

    photos.each do |photo|
      variants.each do |variant|
        record = existing[[ photo.id, variant ]]
        photo.cache_short_url(variant, record) if record
      end
    end
  end

  # One INSERT for every missing row. Tokens are random enough that a collision
  # is vanishingly unlikely; the unique index is the real guard, and a conflict
  # simply falls back to creating the stragglers one at a time.
  def self.bulk_create(rows)
    now = Time.current
    attributes = rows.map do |row|
      {
        token: SecureRandom.urlsafe_base64(TOKEN_BYTES),
        resource_type: "Photo",
        resource_id: row[:resource_id],
        variant: row[:variant],
        expires_at: 7.days.from_now,
        access_count: 0,
        created_at: now,
        updated_at: now
      }
    end

    insert_all!(attributes)
    where(token: attributes.pluck(:token)).to_a
  rescue ActiveRecord::RecordNotUnique
    rows.filter_map do |row|
      create(resource_type: "Photo", resource_id: row[:resource_id], variant: row[:variant])
    end
  end

  # Get the actual resource
  def resource
    case resource_type
    when "Photo"
      Photo.find_by(id: resource_id)
    else
      nil
    end
  end

  # Check if the resource and variant are available
  def available?
    return false unless resource

    case resource_type
    when "Photo"
      photo = resource
      photo&.image&.attached?
    else
      false
    end
  end

  # Mark as accessed
  def track_access!
    update_columns(
      accessed_at: Time.current,
      access_count: access_count + 1
    )
  end

  # Check if expired
  def expired?
    expires_at <= Time.current
  end

  # Generate short URL path
  def short_path
    "/s/#{token}"
  end

  # Generate full short URL
  def short_url(host = nil)
    host ||= Rails.application.config.default_url_options[:host] || "localhost:3000"
    protocol = Rails.env.production? ? "https" : "http"
    "#{protocol}://#{host}#{short_path}"
  end

  # Cleanup expired URLs
  def self.cleanup_expired!
    expired.delete_all
  end

  private

  def generate_token
    loop do
      self.token = SecureRandom.urlsafe_base64(8)
      break unless self.class.exists?(token: token)
    end
  end

  def set_default_expiry
    self.expires_at ||= 7.days.from_now
  end
end
