class ShortUrl < ApplicationRecord
  validates :token, presence: true, uniqueness: true
  validates :resource_type, presence: true
  validates :resource_id, presence: true
  validates :expires_at, presence: true
  
  # Scopes
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :for_resource, ->(resource_type, resource_id) { where(resource_type: resource_type, resource_id: resource_id) }
  
  # Generate a short token
  before_validation :generate_token, on: :create
  before_validation :set_default_expiry, on: :create
  
  # Find or create a short URL for a resource
  def self.for_photo_variant(photo, variant_name)
    existing = active.for_resource('Photo', photo.id).find_by(variant: variant_name.to_s)
    return existing if existing
    
    create!(
      resource_type: 'Photo',
      resource_id: photo.id,
      variant: variant_name.to_s
    )
  end
  
  # Get the actual resource
  def resource
    case resource_type
    when 'Photo'
      Photo.find_by(id: resource_id)
    else
      nil
    end
  end
  
  # Check if the resource and variant are available
  def available?
    return false unless resource
    
    case resource_type
    when 'Photo'
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
    host ||= Rails.application.config.default_url_options[:host] || 'localhost:3000'
    protocol = Rails.env.production? ? 'https' : 'http'
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
