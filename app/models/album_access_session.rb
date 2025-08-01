class AlbumAccessSession < ApplicationRecord
  belongs_to :album

  # Guest sessions expire after 10 minutes of inactivity
  SESSION_DURATION = 10.minutes

  validates :session_token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :accessed_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :recent, -> { order(accessed_at: :desc) }

  # Clean up expired sessions periodically
  scope :cleanup_expired, -> { expired.delete_all }

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

  # Check if session is still valid and extend if activity detected
  def valid_with_activity_check!
    return false if expired?
    extend_session!
    true
  end
end
