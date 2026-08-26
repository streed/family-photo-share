class AlbumAccessSession < ApplicationRecord
  belongs_to :album

  # Guest sessions expire after this long without activity. Every message and
  # countdown that quotes a duration derives from this constant, so the number
  # only has to change here.
  SESSION_DURATION = 30.minutes

  validates :session_token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :accessed_at, presence: true

  # How long a session lasts, phrased for a guest. Kept next to the constant so
  # the number in the copy cannot drift away from the number being enforced.
  def self.duration_in_words
    minutes = (SESSION_DURATION / 60).to_i
    "#{minutes} #{'minute'.pluralize(minutes)}"
  end

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :recent, -> { order(accessed_at: :desc) }

  # Clean up expired sessions periodically
  scope :cleanup_expired, -> { expired.delete_all }

  after_create_commit :resolve_ip_location

  # Roughly where this guest is, from their IP. Nil until the lookup lands.
  def location
    return nil if ip_address.blank?

    @location ||= IpLocation.for_ip(ip_address)
  end

  def expired?
    expires_at < Time.current
  end

  def expires_in_minutes
    return 0 if expired?
    ((expires_at - Time.current) / 1.minute).round(1)
  end

  def expires_in_seconds
    return 0 if expired?
    (expires_at - Time.current).to_i
  end

  def touch_access!
    now = Time.current
    update_columns(
      accessed_at: now,
      expires_at: now + SESSION_DURATION
    )
  end

  def extend_session!
    touch_access!
  end

  # Push the expiry out, but only once the session is past its halfway point.
  #
  # Guest image requests arrive a whole grid at a time, so touching on every one
  # would mean an UPDATE per tile. Without any extension on this path, though, a
  # guest watching a slideshow makes no page requests at all and gets cut off
  # mid-view with every remaining photo turning into a 403.
  def extend_if_stale!
    return false if expires_at - Time.current > SESSION_DURATION / 2

    touch_access!
    true
  end

  # Check if session is still valid and extend if activity detected
  def valid_with_activity_check!
    return false if expired?
    extend_session!
    true
  end

  private

  def resolve_ip_location
    IpLocation.resolve_later(ip_address)
  end
end
