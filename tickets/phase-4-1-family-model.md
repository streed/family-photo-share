# Phase 4, Ticket 1: Family Model and Memberships

**Priority**: High  
**Estimated Time**: 3-4 hours  
**Prerequisites**: Completed Phase 3  

## Objective

Create the Family model and FamilyMembership join model to enable users to organize into families with role-based permissions (owner, editor, viewer).

## Acceptance Criteria

- [ ] Family model created with necessary attributes
- [ ] FamilyMembership join model with role-based permissions
- [ ] User can belong to multiple families
- [ ] Family owner/editor/viewer roles properly implemented
- [ ] Family creation and management functionality
- [ ] Proper validations and constraints
- [ ] Tests for all family-related functionality

## Technical Requirements

### 1. Create Family Model
```bash
bundle exec rails generate model Family name:string description:text created_by:references
```

Update the migration:
```ruby
class CreateFamilies < ActiveRecord::Migration[7.0]
  def change
    create_table :families do |t|
      t.string :name, null: false
      t.text :description
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :invite_code, index: { unique: true }
      t.datetime :invite_code_expires_at

      t.timestamps
    end

    add_index :families, :name
  end
end
```

### 2. Create FamilyMembership Model
```bash
bundle exec rails generate model FamilyMembership family:references user:references role:string
```

Update the migration:
```ruby
class CreateFamilyMemberships < ActiveRecord::Migration[7.0]
  def change
    create_table :family_memberships do |t|
      t.references :family, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'viewer'
      t.datetime :joined_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.references :invited_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :family_memberships, [:family_id, :user_id], unique: true
    add_index :family_memberships, :role
  end
end
```

### 3. Update Family Model
Update `app/models/family.rb`:

```ruby
class Family < ApplicationRecord
  belongs_to :created_by, class_name: 'User'
  has_many :family_memberships, dependent: :destroy
  has_many :members, through: :family_memberships, source: :user
  has_many :photos, through: :members

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }
  validates :invite_code, uniqueness: true, allow_nil: true

  # Callbacks
  before_create :generate_invite_code
  after_create :add_creator_as_owner

  # Scopes
  scope :by_name, -> { order(:name) }

  # Role-based member queries
  def owners
    members.joins(:family_memberships)
           .where(family_memberships: { family: self, role: 'owner' })
  end

  def editors
    members.joins(:family_memberships)
           .where(family_memberships: { family: self, role: ['owner', 'editor'] })
  end

  def viewers
    members.joins(:family_memberships)
           .where(family_memberships: { family: self, role: ['owner', 'editor', 'viewer'] })
  end

  # Check if user has specific role or higher
  def user_role(user)
    membership = family_memberships.find_by(user: user)
    membership&.role
  end

  def user_can_edit?(user)
    ['owner', 'editor'].include?(user_role(user))
  end

  def user_can_manage?(user)
    user_role(user) == 'owner'
  end

  def user_can_view?(user)
    members.include?(user)
  end

  # Invite code management
  def regenerate_invite_code!
    generate_invite_code
    save!
  end

  def invite_code_valid?
    invite_code_expires_at.nil? || invite_code_expires_at > Time.current
  end

  # Member management
  def add_member(user, role: 'viewer', invited_by: nil)
    return false if members.include?(user)

    family_memberships.create!(
      user: user,
      role: role,
      invited_by: invited_by
    )
  end

  def remove_member(user)
    return false if created_by == user # Cannot remove family creator
    
    membership = family_memberships.find_by(user: user)
    membership&.destroy
  end

  def change_member_role(user, new_role)
    return false if created_by == user && new_role != 'owner' # Creator must remain owner
    
    membership = family_memberships.find_by(user: user)
    membership&.update(role: new_role)
  end

  # Stats
  def member_count
    family_memberships.count
  end

  def photo_count
    photos.count
  end

  private

  def generate_invite_code
    loop do
      self.invite_code = SecureRandom.hex(8).upcase
      break unless Family.exists?(invite_code: invite_code)
    end
    self.invite_code_expires_at = 7.days.from_now
  end

  def add_creator_as_owner
    family_memberships.create!(
      user: created_by,
      role: 'owner'
    )
  end
end
```

### 4. Update FamilyMembership Model
Update `app/models/family_membership.rb`:

```ruby
class FamilyMembership < ApplicationRecord
  belongs_to :family
  belongs_to :user
  belongs_to :invited_by, class_name: 'User', optional: true

  # Define valid roles
  ROLES = %w[owner editor viewer].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :family_id, message: "is already a member of this family" }

  # Scopes
  scope :owners, -> { where(role: 'owner') }
  scope :editors, -> { where(role: ['owner', 'editor']) }
  scope :viewers, -> { where(role: ['owner', 'editor', 'viewer']) }
  scope :recent, -> { order(joined_at: :desc) }

  # Role checking methods
  def owner?
    role == 'owner'
  end

  def editor?
    role == 'editor' || owner?
  end

  def viewer?
    ROLES.include?(role)
  end

  # Can this member perform specific actions?
  def can_edit_family?
    owner?
  end

  def can_invite_members?
    owner? || editor?
  end

  def can_edit_photos?
    owner? || editor?
  end

  def can_view_photos?
    viewer?
  end

  # Role hierarchy for role changes
  def self.role_hierarchy
    { 'viewer' => 0, 'editor' => 1, 'owner' => 2 }
  end

  def role_level
    self.class.role_hierarchy[role] || 0
  end

  def higher_role_than?(other_role)
    role_level > (self.class.role_hierarchy[other_role] || 0)
  end
end
```

### 5. Update User Model
Update `app/models/user.rb` to add family associations:

```ruby
class User < ApplicationRecord
  # ... existing code ...

  # Family associations
  has_many :family_memberships, dependent: :destroy
  has_many :families, through: :family_memberships
  has_many :created_families, class_name: 'Family', foreign_key: 'created_by_id', dependent: :destroy
  has_many :invited_memberships, class_name: 'FamilyMembership', foreign_key: 'invited_by_id'

  # ... existing code ...

  # Family-related methods
  def family_role(family)
    membership = family_memberships.find_by(family: family)
    membership&.role
  end

  def member_of?(family)
    families.include?(family)
  end

  def can_edit_family?(family)
    family_role(family) == 'owner'
  end

  def can_invite_to_family?(family)
    ['owner', 'editor'].include?(family_role(family))
  end

  def owned_families
    families.joins(:family_memberships)
            .where(family_memberships: { user: self, role: 'owner' })
  end

  def family_count
    families.count
  end
end
```

### 6. Create Families Controller
Create `app/controllers/families_controller.rb`:

```ruby
class FamiliesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family, only: [:show, :edit, :update, :destroy]
  before_action :check_family_access, only: [:show]
  before_action :check_family_management, only: [:edit, :update, :destroy]

  def index
    @families = current_user.families.by_name.includes(:family_memberships, :members)
  end

  def show
    @members = @family.family_memberships.includes(:user, :invited_by).recent
    @recent_photos = @family.photos.recent.limit(12).includes(:user, image_attachment: :blob)
  end

  def new
    @family = current_user.created_families.build
  end

  def create
    @family = current_user.created_families.build(family_params)

    if @family.save
      redirect_to @family, notice: 'Family created successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Edit family details
  end

  def update
    if @family.update(family_params)
      redirect_to @family, notice: 'Family updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @family.destroy
    redirect_to families_path, notice: 'Family deleted successfully!'
  end

  # Join family via invite code
  def join
    @family = Family.find_by(invite_code: params[:invite_code])

    if @family.nil?
      redirect_to families_path, alert: 'Invalid invite code.'
    elsif !@family.invite_code_valid?
      redirect_to families_path, alert: 'Invite code has expired.'
    elsif current_user.member_of?(@family)
      redirect_to @family, notice: 'You are already a member of this family.'
    else
      @family.add_member(current_user)
      redirect_to @family, notice: 'Successfully joined the family!'
    end
  end

  private

  def set_family
    @family = Family.find(params[:id])
  end

  def check_family_access
    unless @family.user_can_view?(current_user)
      redirect_to families_path, alert: 'You do not have access to this family.'
    end
  end

  def check_family_management
    unless @family.user_can_manage?(current_user)
      redirect_to @family, alert: 'You do not have permission to manage this family.'
    end
  end

  def family_params
    params.require(:family).permit(:name, :description)
  end
end
```

### 7. Create Family Views
Create `app/views/families/index.html.erb`:

```erb
<div class="families-header">
  <h1>My Families</h1>
  <%= link_to "Create New Family", new_family_path, class: "btn btn-primary" %>
</div>

<% if @families.any? %>
  <div class="families-grid">
    <% @families.each do |family| %>
      <div class="family-card">
        <%= link_to family_path(family), class: "family-link" do %>
          <div class="family-info">
            <h3 class="family-name"><%= family.name %></h3>
            <p class="family-description">
              <%= truncate(family.description, length: 100) if family.description.present? %>
            </p>
            
            <div class="family-stats">
              <span class="stat">
                <strong><%= family.member_count %></strong> members
              </span>
              <span class="stat">
                <strong><%= family.photo_count %></strong> photos
              </span>
            </div>

            <div class="family-role">
              <span class="role-badge role-<%= current_user.family_role(family) %>">
                <%= current_user.family_role(family).titleize %>
              </span>
            </div>
          </div>
        <% end %>

        <% if family.user_can_manage?(current_user) %>
          <div class="family-actions">
            <%= link_to "Edit", edit_family_path(family), class: "btn btn-sm btn-secondary" %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
<% else %>
  <div class="empty-state">
    <h2>No families yet</h2>
    <p>Create a family to start sharing photos with your loved ones!</p>
    <%= link_to "Create Your First Family", new_family_path, class: "btn btn-primary btn-lg" %>
  </div>
<% end %>

<div class="join-family-section">
  <h3>Join a Family</h3>
  <p>Have an invite code? Join an existing family:</p>
  
  <%= form_with url: join_family_path, method: :post, local: true, class: "join-form" do |f| %>
    <div class="form-group">
      <%= f.text_field :invite_code, placeholder: "Enter invite code", class: "form-control", required: true %>
      <%= f.submit "Join Family", class: "btn btn-success" %>
    </div>
  <% end %>
</div>
```

Create `app/views/families/show.html.erb`:

```erb
<div class="family-header">
  <div class="family-title">
    <h1><%= @family.name %></h1>
    <% if @family.description.present? %>
      <p class="family-description"><%= simple_format(@family.description) %></p>
    <% end %>
  </div>

  <div class="family-actions">
    <% if @family.user_can_manage?(current_user) %>
      <%= link_to "Edit Family", edit_family_path(@family), class: "btn btn-primary" %>
      <%= link_to "Manage Members", family_members_path(@family), class: "btn btn-secondary" %>
    <% end %>
    
    <% if @family.user_can_edit?(current_user) %>
      <%= link_to "Upload Photos", new_photo_path(family_id: @family.id), class: "btn btn-success" %>
    <% end %>
  </div>
</div>

<div class="family-content">
  <!-- Family Members Section -->
  <div class="family-section">
    <h2>Family Members (<%= @family.member_count %>)</h2>
    
    <div class="members-list">
      <% @members.each do |membership| %>
        <div class="member-card">
          <div class="member-info">
            <% if membership.user.avatar_url.present? %>
              <%= image_tag membership.user.avatar_url, class: "avatar-small" %>
            <% else %>
              <div class="avatar-placeholder avatar-small">
                <%= membership.user.display_name_or_full_name.first.upcase %>
              </div>
            <% end %>
            
            <div class="member-details">
              <strong><%= membership.user.display_name_or_full_name %></strong>
              <span class="role-badge role-<%= membership.role %>">
                <%= membership.role.titleize %>
              </span>
            </div>
          </div>
          
          <div class="member-meta">
            <small>Joined <%= membership.joined_at.strftime("%B %Y") %></small>
            <% if membership.invited_by.present? %>
              <small>Invited by <%= membership.invited_by.display_name_or_full_name %></small>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>

    <% if @family.user_can_edit?(current_user) %>
      <div class="invite-section">
        <h3>Invite New Members</h3>
        <div class="invite-code-section">
          <p>Share this invite code with family members:</p>
          <div class="invite-code">
            <code><%= @family.invite_code %></code>
            <button onclick="copyInviteCode()" class="btn btn-sm btn-outline">Copy</button>
          </div>
          <small>Expires <%= @family.invite_code_expires_at.strftime("%B %d, %Y") %></small>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Recent Photos Section -->
  <div class="family-section">
    <h2>Recent Photos</h2>
    
    <% if @recent_photos.any? %>
      <div class="photos-grid">
        <% @recent_photos.each do |photo| %>
          <div class="photo-card">
            <%= link_to photo_path(photo), class: "photo-link" do %>
              <div class="photo-thumbnail">
                <%= photo_tag(photo, :thumbnail) %>
              </div>
              <div class="photo-info">
                <h4><%= truncate(photo.title, length: 20) %></h4>
                <small>by <%= photo.user.display_name_or_full_name %></small>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      
      <%= link_to "View All Photos", family_photos_path(@family), class: "btn btn-outline" %>
    <% else %>
      <div class="empty-photos">
        <p>No photos shared yet.</p>
        <% if @family.user_can_edit?(current_user) %>
          <%= link_to "Share the first photo", new_photo_path(family_id: @family.id), class: "btn btn-primary" %>
        <% end %>
      </div>
    <% end %>
  </div>
</div>

<script>
function copyInviteCode() {
  const code = '<%= @family.invite_code %>';
  navigator.clipboard.writeText(code).then(() => {
    alert('Invite code copied to clipboard!');
  });
}
</script>
```

Create `app/views/families/new.html.erb`:

```erb
<h1>Create New Family</h1>

<%= form_with model: @family, local: true, class: "family-form" do |f| %>
  <%= render 'form_errors', family: @family %>

  <div class="form-group">
    <%= f.label :name %>
    <%= f.text_field :name, class: "form-control", placeholder: "e.g., The Smith Family" %>
  </div>

  <div class="form-group">
    <%= f.label :description, "Description (optional)" %>
    <%= f.text_area :description, class: "form-control", rows: 3, 
        placeholder: "Tell others about your family..." %>
  </div>

  <div class="form-actions">
    <%= f.submit "Create Family", class: "btn btn-primary" %>
    <%= link_to "Cancel", families_path, class: "btn btn-secondary" %>
  </div>
<% end %>
```

Create `app/views/families/_form_errors.html.erb`:

```erb
<% if family.errors.any? %>
  <div class="error-messages">
    <h4><%= pluralize(family.errors.count, "error") %> prohibited this family from being saved:</h4>
    <ul>
      <% family.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

## Testing Requirements

### 1. Create Family Factory
Create `spec/factories/families.rb`:

```ruby
FactoryBot.define do
  factory :family do
    name { Faker::Lorem.words(number: 2).map(&:capitalize).join(' ') + ' Family' }
    description { Faker::Lorem.paragraph }
    association :created_by, factory: :user

    trait :with_members do
      after(:create) do |family|
        create_list(:family_membership, 3, family: family)
      end
    end
  end
end
```

Create `spec/factories/family_memberships.rb`:

```ruby
FactoryBot.define do
  factory :family_membership do
    association :family
    association :user
    role { 'viewer' }
    joined_at { Time.current }

    trait :owner do
      role { 'owner' }
    end

    trait :editor do
      role { 'editor' }
    end

    trait :viewer do
      role { 'viewer' }
    end
  end
end
```

### 2. Create Model Tests
Create `spec/models/family_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Family, type: :model do
  describe 'associations' do
    it { should belong_to(:created_by).class_name('User') }
    it { should have_many(:family_memberships).dependent(:destroy) }
    it { should have_many(:members).through(:family_memberships) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(500) }
  end

  describe 'callbacks' do
    let(:user) { create(:user) }

    it 'generates invite code before creation' do
      family = build(:family, created_by: user)
      expect(family.invite_code).to be_nil
      family.save!
      expect(family.invite_code).to be_present
    end

    it 'adds creator as owner after creation' do
      family = create(:family, created_by: user)
      expect(family.user_role(user)).to eq('owner')
    end
  end

  describe 'role methods' do
    let(:family) { create(:family) }
    let(:owner) { family.created_by }
    let(:editor) { create(:user) }
    let(:viewer) { create(:user) }

    before do
      family.add_member(editor, role: 'editor')
      family.add_member(viewer, role: 'viewer')
    end

    describe '#user_can_edit?' do
      it 'returns true for owners and editors' do
        expect(family.user_can_edit?(owner)).to be true
        expect(family.user_can_edit?(editor)).to be true
        expect(family.user_can_edit?(viewer)).to be false
      end
    end

    describe '#user_can_manage?' do
      it 'returns true only for owners' do
        expect(family.user_can_manage?(owner)).to be true
        expect(family.user_can_manage?(editor)).to be false
        expect(family.user_can_manage?(viewer)).to be false
      end
    end
  end

  describe '#add_member' do
    let(:family) { create(:family) }
    let(:user) { create(:user) }

    it 'adds a new member successfully' do
      expect {
        family.add_member(user, role: 'editor')
      }.to change(family.members, :count).by(1)

      expect(family.user_role(user)).to eq('editor')
    end

    it 'does not add existing member' do
      family.add_member(user)
      
      expect {
        family.add_member(user)
      }.not_to change(family.members, :count)
    end
  end
end
```

## Files to Create/Modify

- `db/migrate/xxx_create_families.rb` - Family table
- `db/migrate/xxx_create_family_memberships.rb` - Membership join table
- `app/models/family.rb` - Family model with role logic
- `app/models/family_membership.rb` - Membership model
- `app/models/user.rb` - Add family associations
- `app/controllers/families_controller.rb` - Family management
- `app/views/families/` - Family views
- `spec/factories/families.rb` - Family factory
- `spec/factories/family_memberships.rb` - Membership factory
- `spec/models/family_spec.rb` - Family model tests

## Deliverables

1. Complete family management system
2. Role-based permissions (owner/editor/viewer)
3. Family creation and joining via invite codes
4. Member management interface
5. Comprehensive test coverage

## Next Steps

After completing this ticket, you'll move to Phase 4, Ticket 2: Family Member Management and Invitations.