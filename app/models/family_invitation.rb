class FamilyInvitation < ApplicationRecord
  belongs_to :family
  belongs_to :inviter, class_name: "User"

  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[pending accepted declined expired] }
  validates :expires_at, presence: true
  validates :email, uniqueness: { scope: :family_id, conditions: -> { where(status: "pending") } }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :accepted, -> { where(status: "accepted") }
  scope :declined, -> { where(status: "declined") }
  scope :expired, -> { where(status: "expired") }
  scope :active, -> { where(status: "pending").where("expires_at > ?", Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  # Instance methods
  def pending?
    status == "pending"
  end

  def accepted?
    status == "accepted"
  end

  def declined?
    status == "declined"
  end

  def expired?
    status == "expired" || expires_at < Time.current
  end

  def accept!(user = nil)
    return false if expired?
    return false if user && user.has_family?

    # If user is provided, create membership for them
    if user && user.email == email
      family.family_memberships.create!(
        user: user,
        role: "member",
        joined_at: Time.current
      )
    end

    update!(status: "accepted")
  end

  def decline!
    return false if expired?
    update!(status: "declined")
  end

  def expire!
    update!(status: "expired")
  end

  def invited_user
    User.find_by(email: email)
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at = 7.days.from_now
  end
end
