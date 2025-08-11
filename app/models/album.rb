class Album < ApplicationRecord
  belongs_to :user
  belongs_to :cover_photo, class_name: "Photo", optional: true

  has_many :album_photos, dependent: :destroy
  has_many :photos, through: :album_photos
  has_many :album_access_sessions, dependent: :destroy
  has_many :album_view_events, dependent: :destroy

  # Virtual attribute for password
  attr_accessor :password

  # Save password as plain text
  before_save :set_external_password, if: :password

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }
  validates :privacy, presence: true, inclusion: { in: %w[private family] }
  validates :name, uniqueness: { scope: :user_id }
  validates :password, length: { minimum: 6 }, if: -> { allow_external_access? && password.present? }
  validates :sharing_token, uniqueness: true, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_privacy, ->(privacy) { where(privacy: privacy) }
  scope :private_albums, -> { where(privacy: "private") }
  scope :family_albums, -> { where(privacy: "family") }

  before_save :generate_sharing_token, if: :allow_external_access_changed?
  before_save :clear_sharing_data, if: :allow_external_access_changed_to_false?
  after_update :update_cover_photo_if_needed
  # Callbacks
  before_destroy :remove_cover_photo_reference

  # Instance methods
  def photo_count
    album_photos.count
  end

  def ordered_photos
    Photo.select("photos.*")
         .joins(:album_photos)
         .where(album_photos: { album_id: id })
         .order("photos.taken_at DESC NULLS LAST, photos.created_at DESC")
  end

  def add_photo(photo, position = nil)
    return false if photos.include?(photo)

    position ||= next_position
    album_photos.create!(
      photo: photo,
      position: position,
      added_at: Time.current
    )

    # Set as cover photo if this is the first photo
    update!(cover_photo: photo) if cover_photo.nil?

    true
  end

  def remove_photo(photo)
    album_photo = album_photos.find_by(photo: photo)
    return false unless album_photo

    Rails.logger.info "Found album_photo record #{album_photo.id} for photo #{photo.id} in album #{id}"

    # If removing cover photo, set new cover
    if cover_photo == photo
      Rails.logger.info "Removing cover photo, setting new cover"
      new_cover = ordered_photos.where.not(id: photo.id).first
      if new_cover
        update!(cover_photo: new_cover)
        Rails.logger.info "Set new cover photo to #{new_cover.id}"
      else
        update!(cover_photo: nil)
        Rails.logger.info "No other photos available, cleared cover photo"
      end
    end

    Rails.logger.info "Destroying album_photo record #{album_photo.id}"
    album_photo.destroy!

    Rails.logger.info "Reordering positions after photo removal"
    reorder_positions

    Rails.logger.info "Successfully removed photo #{photo.id} from album #{id}"
    true
  rescue => e
    Rails.logger.error "Error in remove_photo: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  def move_photo(photo, new_position)
    album_photo = album_photos.find_by(photo: photo)
    return false unless album_photo

    album_photo.update!(position: new_position)
    reorder_positions
    true
  end

  def set_cover_photo(photo)
    return false unless photos.include?(photo)
    update_column(:cover_photo_id, photo.id)
    true
  end

  def accessible_by?(user)
    return true if self.user == user
    return true if privacy == "family" && user&.family == self.user.family
    false
  end

  def editable_by?(user)
    self.user == user
  end

  # External sharing methods
  def sharing_url
    return nil unless allow_external_access? && sharing_token.present?
    Rails.application.routes.url_helpers.external_album_url(token: sharing_token, host: Rails.application.config.action_mailer.default_url_options[:host], port: Rails.application.config.action_mailer.default_url_options[:port])
  end

  def accessible_externally_with_password?(password_attempt)
    return false unless allow_external_access? && external_password.present?
    external_password == password_attempt
  end

  def create_access_session(ip_address)
    token = SecureRandom.urlsafe_base64(32)
    # Guest sessions expire after 10 minutes
    expires_at = AlbumAccessSession::SESSION_DURATION.from_now

    album_access_sessions.create!(
      session_token: token,
      ip_address: ip_address,
      expires_at: expires_at,
      accessed_at: Time.current
    )
  end

  def valid_access_session?(session_token)
    return false if session_token.blank?

    session = album_access_sessions.find_by(session_token: session_token)
    return false unless session
    return false if session.expires_at < Time.current

    # Update last accessed time
    session.update_column(:accessed_at, Time.current)
    true
  end

  def revoke_all_access_sessions
    album_access_sessions.delete_all
  end

  def disable_external_access!
    update!(
      allow_external_access: false,
      external_password: nil,
      sharing_token: nil
    )
    revoke_all_access_sessions
  end

  private

  def next_position
    (album_photos.maximum(:position) || 0) + 1
  end

  def reorder_positions
    album_photos.order(:position).each_with_index do |ap, index|
      ap.update_column(:position, index + 1) if ap.position != index + 1
    end
  end

  def remove_cover_photo_reference
    update_column(:cover_photo_id, nil) if cover_photo_id.present?
  end

  def update_cover_photo_if_needed
    # If cover photo is no longer in album, update it
    if cover_photo_id.present? && !photos.exists?(cover_photo_id)
      new_cover = ordered_photos.first
      update_column(:cover_photo_id, new_cover&.id)
    end
  end

  def generate_sharing_token
    return unless allow_external_access?
    self.sharing_token = SecureRandom.urlsafe_base64(16) while sharing_token.blank? || Album.exists?(sharing_token: sharing_token)
  end

  def clear_sharing_data
    return unless allow_external_access_changed_to_false?
    self.external_password = nil
    self.sharing_token = nil
    revoke_all_access_sessions
  end

  def set_external_password
    self.external_password = password if password.present?
  end

  def allow_external_access_changed_to_false?
    allow_external_access_changed? && !allow_external_access?
  end
end
