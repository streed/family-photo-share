class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :lockable

  # Validations
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :display_name, length: { maximum: 50 }
  validates :bio, length: { maximum: 500 }
  validates :phone_number, format: { with: /\A[\+]?[1-9][\d\s\-\(\)]+\z/, message: "Invalid phone format" }, allow_blank: true
  validates :password, length: { minimum: 6 }, if: :password_required?


  # Associations
  has_many :photos, dependent: :destroy
  has_many :albums, dependent: :destroy
  has_many :bulk_uploads, dependent: :destroy
  has_many :created_families, class_name: "Family", foreign_key: "created_by_id", dependent: :destroy
  has_one :family_membership, dependent: :destroy
  has_one :family, through: :family_membership
  has_many :sent_invitations, class_name: "FamilyInvitation", foreign_key: "inviter_id", dependent: :destroy
  has_many :received_invitations, class_name: "FamilyInvitation", primary_key: "email", foreign_key: "email"

  # Callbacks
  before_save :set_display_name

  # Class methods
  def self.password_length
    6..128
  end

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name_or_full_name
    display_name.presence || full_name
  end


  # Photo-related methods
  def recent_photos(limit = 10)
    photos.recent.limit(limit)
  end

  def photo_count
    photos.count
  end

  # Family-related methods
  def has_family?
    family.present?
  end

  def admin_of_family?
    family_membership&.admin? || false
  end

  def member_of?(check_family)
    family == check_family
  end

  def pending_invitations
    received_invitations.active
  end

  def can_invite?
    admin_of_family?
  end

  def can_create_family?
    !has_family?
  end

  def can_join_family?
    !has_family?
  end

  def family_role
    family_membership&.role
  end

  def family_admin?
    family_membership&.admin? || false
  end

  # Album-related methods
  def album_count
    albums.count
  end

  def recent_albums(limit = 10)
    albums.recent.limit(limit)
  end

  # Admin methods for console use
  def reset_password!(new_password)
    self.password = new_password
    self.password_confirmation = new_password
    save(validate: false)
  end

  def reset_password_with_validation!(new_password)
    self.password = new_password
    self.password_confirmation = new_password
    save!
  end

  private

  def set_display_name
    self.display_name = full_name if display_name.blank?
  end

  def password_required?
    !persisted? || password.present? || password_confirmation.present?
  end
end
