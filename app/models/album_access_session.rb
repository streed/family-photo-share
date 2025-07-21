class AlbumAccessSession < ApplicationRecord
  belongs_to :album
  
  validates :session_token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :accessed_at, presence: true
  
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :recent, -> { order(accessed_at: :desc) }
  
  # Clean up expired sessions periodically
  scope :cleanup_expired, -> { expired.delete_all }
  
  def expired?
    expires_at < Time.current
  end
  
  def expires_in
    return 0 if expired?
    ((expires_at - Time.current) / 1.hour).round(1)
  end
  
  def touch_access!
    update_column(:accessed_at, Time.current)
  end
end