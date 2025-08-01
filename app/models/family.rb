class Family < ApplicationRecord
  belongs_to :created_by, class_name: "User"

  has_many :family_memberships, dependent: :destroy
  has_many :members, through: :family_memberships, source: :user
  has_many :family_invitations, dependent: :destroy
  has_many :shared_photos, through: :members, source: :photos

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  after_create :add_creator_as_admin

  # Instance methods
  def admin?(user)
    family_memberships.find_by(user: user)&.role == "admin"
  end

  def member?(user)
    family_memberships.exists?(user: user)
  end

  def member_count
    family_memberships.count
  end

  def recent_photos(limit = 10)
    shared_photos.recent.limit(limit)
  end

  private

  def add_creator_as_admin
    family_memberships.create!(
      user: created_by,
      role: "admin",
      joined_at: Time.current
    )
  end
end
