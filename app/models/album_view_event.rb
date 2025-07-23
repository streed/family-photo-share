class AlbumViewEvent < ApplicationRecord
  belongs_to :album
  belongs_to :photo, optional: true

  EVENT_TYPES = {
    password_entry: 'password_entry',
    password_attempt_failed: 'password_attempt_failed',
    photo_view: 'photo_view'
  }.freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES.values }
  validates :occurred_at, presence: true

  scope :recent, -> { where(occurred_at: 7.days.ago..) }
  scope :for_album, ->(album) { where(album: album) }
  scope :by_type, ->(type) { where(event_type: type) }

  before_validation :set_occurred_at

  def self.track_password_entry(album, request, session_id)
    create!(
      album: album,
      event_type: EVENT_TYPES[:password_entry],
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referrer: request.referrer,
      session_id: session_id,
      occurred_at: Time.current
    )
  end

  def self.track_failed_password_attempt(album, request)
    create!(
      album: album,
      event_type: EVENT_TYPES[:password_attempt_failed],
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referrer: request.referrer,
      session_id: request.session.id&.to_s || 'anonymous',
      occurred_at: Time.current
    )
  end

  def self.track_photo_view(album, photo, request, session_id)
    create!(
      album: album,
      photo: photo,
      event_type: EVENT_TYPES[:photo_view],
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referrer: request.referrer,
      session_id: session_id,
      occurred_at: Time.current
    )
  end

  private

  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end
