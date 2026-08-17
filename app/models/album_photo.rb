class AlbumPhoto < ApplicationRecord
  belongs_to :album, counter_cache: :album_photos_count
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

  # The column defaults to 0, and 0.blank? is false — so this guard never fired
  # and creating an AlbumPhoto without an explicit position failed the
  # "greater than 0" validation instead of being assigned the next slot.
  def set_position
    return if position.to_i.positive?

    max_position = album&.album_photos&.maximum(:position) || 0
    self.position = max_position + 1
  end
end
