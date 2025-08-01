class AlbumPhoto < ApplicationRecord
  belongs_to :album
  belongs_to :photo

  # Validations
  validates :position, presence: true, numericality: { greater_than: 0 }
  validates :added_at, presence: true
  validates :photo_id, uniqueness: { scope: :album_id }

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :recent, -> { order(added_at: :desc) }

  # Callbacks
  before_validation :set_added_at, on: :create
  before_validation :set_position, on: :create

  private

  def set_added_at
    self.added_at ||= Time.current
  end

  def set_position
    if position.blank?
      max_position = album.album_photos.maximum(:position) || 0
      self.position = max_position + 1
    end
  end
end
