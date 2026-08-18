class Album < ApplicationRecord
  belongs_to :user
  belongs_to :cover_photo, class_name: "Photo", optional: true

  has_many :album_photos, dependent: :destroy
  has_many :photos, through: :album_photos
  has_many :album_access_sessions, dependent: :destroy
  has_many :album_view_events, dependent: :destroy

  # The password guests type to open a shared album. Deliberately short and
  # stored in the clear: the owner reads it out over the phone, and it guards
  # family photos rather than an account.
  EXTERNAL_PASSWORD_MIN_LENGTH = 3

  # Virtual attribute for password
  attr_accessor :password

  # Save password as plain text
  before_save :set_external_password, if: :password

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }
  validates :privacy, presence: true, inclusion: { in: %w[private family] }
  validates :name, uniqueness: { scope: :user_id }
  validates :password, length: { minimum: EXTERNAL_PASSWORD_MIN_LENGTH },
                       if: -> { allow_external_access? && password.present? }
  validates :sharing_token, uniqueness: true, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_privacy, ->(privacy) { where(privacy: privacy) }
  scope :private_albums, -> { where(privacy: "private") }
  scope :family_albums, -> { where(privacy: "family") }
  scope :accessible_to, ->(user) {
    return none unless user
    if user.family
      family_user_ids = user.family.users.select(:id)
      where("albums.user_id = :uid OR (albums.privacy = 'family' AND albums.user_id IN (:fids))",
            uid: user.id, fids: family_user_ids)
    else
      where(user_id: user.id)
    end
  }

  before_save :generate_sharing_token, if: :allow_external_access_changed?
  before_save :clear_sharing_data, if: :allow_external_access_changed_to_false?
  after_update :update_cover_photo_if_needed
  # Callbacks
  before_destroy :remove_cover_photo_reference

  # Instance methods
  # Backed by a counter cache: this is read several times per album page and once
  # per tile on the albums index, and each call used to be its own COUNT(*).
  def photo_count
    album_photos_count
  end

  SORT_ORDERS = %w[position date_taken].freeze
  DEFAULT_SORT_ORDER = "position".freeze

  # Photos in the album, in the album's own order.
  #
  # This used to sort purely by photos.taken_at, which made album_photos.position
  # dead weight and produced the app's most confusing behaviour: a photo you just
  # added landed wherever its EXIF date fell (often buried mid-grid), and then
  # moved *again* minutes later when ExtractPhotoMetadataJob backfilled taken_at.
  # Ordering by position keeps a photo where the user put it; "date_taken"
  # remains available for people who want a chronological album.
  def ordered_photos(sort: nil)
    scope = Photo.select("photos.*, album_photos.position AS album_position")
                 .joins(:album_photos)
                 .where(album_photos: { album_id: id })

    if sort_order_for(sort) == "date_taken"
      scope.order("photos.taken_at DESC NULLS LAST, photos.created_at DESC")
    else
      scope.order("album_photos.position ASC, album_photos.added_at ASC")
    end
  end

  def sort_order_for(requested)
    SORT_ORDERS.include?(requested.to_s) ? requested.to_s : DEFAULT_SORT_ORDER
  end

  def add_photo(photo, position = nil)
    # exists? rather than photos.include?, which loaded every photo in the album
    # into memory just to answer a membership question.
    return false if album_photos.exists?(photo_id: photo.id)

    position ||= next_position
    album_photos.create!(
      photo: photo,
      position: position,
      added_at: Time.current
    )

    # Set as cover photo if this is the first photo
    update!(cover_photo: photo) if cover_photo_id.nil?

    true
  end

  # Removes a photo from this album, reassigning the cover if needed.
  #
  # Returns false only when the photo genuinely isn't in the album. Real errors
  # are allowed to propagate: this used to `rescue => e` everything and return
  # false, so a programmer error and "that photo isn't here" produced the same
  # generic "Unable to remove photo from album." message and the bug stayed
  # invisible.
  def remove_photo(photo)
    album_photo = album_photos.find_by(photo: photo)
    return false unless album_photo

    transaction do
      # If removing the cover photo, promote the next one in album order.
      if cover_photo_id == photo.id
        new_cover = ordered_photos.where.not(photos: { id: photo.id }).first
        update!(cover_photo: new_cover)
      end

      album_photo.destroy!
      reorder_positions!
    end

    true
  end

  # Moves a photo to a 1-based slot in the album, shifting the others around it.
  #
  # The old implementation just wrote new_position onto the row and re-sequenced
  # by `order(:position)`. That leaves two rows sharing a position, and the tie is
  # broken arbitrarily by the database — so moving a photo often did nothing.
  def move_photo(photo, new_position)
    ordered = album_photos.order(:position, :added_at).to_a
    album_photo = ordered.find { |ap| ap.photo_id == photo.id }
    return false unless album_photo

    target = new_position.to_i.clamp(1, ordered.size)

    ordered.delete(album_photo)
    ordered.insert(target - 1, album_photo)

    transaction do
      ordered.each_with_index do |ap, index|
        ap.update_column(:position, index + 1) if ap.position != index + 1
      end
    end

    true
  end

  def set_cover_photo(photo)
    return false unless photos.include?(photo)
    update_column(:cover_photo_id, photo.id)
    true
  end

  def accessible_by?(user)
    return false unless user
    return true if self.user == user
    return false unless privacy == "family"

    # Both sides must actually be in a family. Comparing two nils would
    # otherwise let any family-less user read a family-less owner's album.
    owner_family = self.user.family
    owner_family.present? && user.family == owner_family
  end

  def editable_by?(user)
    self.user == user
  end

  # The people who can actually open this album because of its privacy setting,
  # excluding the owner. Used to tell the owner who they are really sharing with.
  def family_viewers
    return [] unless privacy == "family"

    family = user.family
    return [] if family.blank?

    family.users.where.not(id: user_id).to_a
  end

  # External sharing methods
  def sharing_url
    return nil unless allow_external_access? && sharing_token.present?
    Rails.application.routes.url_helpers.external_album_url(token: sharing_token, host: Rails.application.config.action_mailer.default_url_options[:host], port: Rails.application.config.action_mailer.default_url_options[:port])
  end

  def accessible_externally_with_password?(password_attempt)
    return false unless allow_external_access? && external_password.present?
    return false if password_attempt.blank?

    if external_password_hashed?
      BCrypt::Password.new(external_password) == password_attempt
    else
      # Albums shared before passwords were hashed still hold the plaintext.
      # Comparing those through BCrypt raised InvalidHash, which 500'd a guest
      # who typed the CORRECT password.
      ActiveSupport::SecurityUtils.secure_compare(external_password, password_attempt)
    end
  end

  # bcrypt digests are always "$2<x>$<cost>$<53 chars>".
  def external_password_hashed?
    external_password.to_s.start_with?("$2a$", "$2b$", "$2y$")
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

  def reorder_positions!
    album_photos.order(:position).each_with_index do |ap, index|
      ap.update_column(:position, index + 1) if ap.position != index + 1
    end
  end

  private

  def next_position
    (album_photos.maximum(:position) || 0) + 1
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

  # Stored in the clear on purpose: the owner has to be able to read the password
  # back to pass it along with the share link, and the album show page displays
  # it with a copy button. Hashing it breaks that workflow.
  def set_external_password
    self.external_password = password if password.present?
  end

  def allow_external_access_changed_to_false?
    allow_external_access_changed? && !allow_external_access?
  end
end
