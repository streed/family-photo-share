class FamilyMembership < ApplicationRecord
  belongs_to :user
  belongs_to :family

  # Validations
  validates :role, presence: true, inclusion: { in: %w[admin member] }
  validates :joined_at, presence: true
  validates :user_id, uniqueness: { message: "can only belong to one family" }

  # Callbacks
  before_validation :set_joined_at, on: :create

  # Custom validation
  validate :user_can_join_family, on: :create

  # Scopes
  scope :admins, -> { where(role: "admin") }
  scope :members, -> { where(role: "member") }
  scope :recent, -> { order(joined_at: :desc) }

  # Instance methods
  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end

  def can_invite?
    admin?
  end

  def can_manage_members?
    admin?
  end

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end

  def user_can_join_family
    if user && user.has_family? && user.family != family
      errors.add(:user, "already belongs to another family")
    end
  end
end
