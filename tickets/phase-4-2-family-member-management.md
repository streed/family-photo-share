# Phase 4, Ticket 2: Family Member Management and Email Invitations

**Priority**: High  
**Estimated Time**: 3-4 hours  
**Prerequisites**: Completed Phase 4, Ticket 1  

## Objective

Implement comprehensive family member management including email invitations, role changes, member removal, and invitation tracking with background job processing.

## Acceptance Criteria

- [ ] Email invitation system for non-users
- [ ] Member role management (promote/demote)
- [ ] Member removal functionality
- [ ] Invitation tracking and management
- [ ] Background job processing for emails
- [ ] Invitation acceptance workflow
- [ ] Comprehensive member management interface
- [ ] Email templates for invitations

## Technical Requirements

### 1. Create Invitation Model
```bash
bundle exec rails generate model FamilyInvitation family:references invited_by:references email:string role:string token:string expires_at:datetime accepted_at:datetime
```

Update the migration:
```ruby
class CreateFamilyInvitations < ActiveRecord::Migration[7.0]
  def change
    create_table :family_invitations do |t|
      t.references :family, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :role, null: false, default: 'viewer'
      t.string :token, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.text :message

      t.timestamps
    end

    add_index :family_invitations, [:family_id, :email], unique: true, 
              where: "accepted_at IS NULL", name: "index_pending_invitations"
    add_index :family_invitations, :expires_at
  end
end
```

### 2. Update FamilyInvitation Model
Update `app/models/family_invitation.rb`:

```ruby
class FamilyInvitation < ApplicationRecord
  belongs_to :family
  belongs_to :invited_by, class_name: 'User'

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: FamilyMembership::ROLES }
  validates :token, presence: true, uniqueness: true
  validates :email, uniqueness: { scope: :family_id, conditions: -> { where(accepted_at: nil) },
                                  message: "already has a pending invitation to this family" }

  # Scopes
  scope :pending, -> { where(accepted_at: nil, expires_at: Time.current..) }
  scope :expired, -> { where(accepted_at: nil, expires_at: ..Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create
  after_create :send_invitation_email

  # Status methods
  def pending?
    accepted_at.nil? && !expired?
  end

  def expired?
    expires_at < Time.current
  end

  def accepted?
    accepted_at.present?
  end

  # Accept invitation
  def accept!(user)
    return false if expired? || accepted?
    return false if user.email != email

    transaction do
      # Add user to family
      family.add_member(user, role: role, invited_by: invited_by)
      
      # Mark invitation as accepted
      update!(accepted_at: Time.current)
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Resend invitation
  def resend!
    return false unless pending?
    
    update!(
      expires_at: 7.days.from_now,
      updated_at: Time.current
    )
    
    send_invitation_email
    true
  end

  private

  def generate_token
    loop do
      self.token = SecureRandom.urlsafe_base64(32)
      break unless FamilyInvitation.exists?(token: token)
    end
  end

  def set_expiry
    self.expires_at = 7.days.from_now
  end

  def send_invitation_email
    FamilyInvitationMailer.invitation_email(self).deliver_later
  end
end
```

### 3. Create Family Members Controller
Create `app/controllers/family_members_controller.rb`:

```ruby
class FamilyMembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family
  before_action :check_management_permission
  before_action :set_member, only: [:show, :update, :destroy]

  def index
    @members = @family.family_memberships.includes(:user, :invited_by).recent
    @invitations = @family.family_invitations.pending.recent
    @invitation = @family.family_invitations.build
  end

  def show
    # Member detail view
  end

  def update
    # Update member role
    new_role = params[:role]
    
    if valid_role_change?(new_role)
      if @family.change_member_role(@member.user, new_role)
        redirect_to family_members_path(@family), 
                    notice: "#{@member.user.display_name_or_full_name}'s role updated to #{new_role.titleize}."
      else
        redirect_to family_members_path(@family), 
                    alert: "Failed to update member role."
      end
    else
      redirect_to family_members_path(@family), 
                  alert: "Invalid role change."
    end
  end

  def destroy
    # Remove member from family
    if @member.user == @family.created_by
      redirect_to family_members_path(@family), 
                  alert: "Cannot remove the family creator."
    elsif @family.remove_member(@member.user)
      redirect_to family_members_path(@family), 
                  notice: "#{@member.user.display_name_or_full_name} removed from family."
    else
      redirect_to family_members_path(@family), 
                  alert: "Failed to remove member."
    end
  end

  # Send email invitation
  def invite
    @invitation = @family.family_invitations.build(invitation_params)
    @invitation.invited_by = current_user

    if @invitation.save
      redirect_to family_members_path(@family), 
                  notice: "Invitation sent to #{@invitation.email}."
    else
      @members = @family.family_memberships.includes(:user, :invited_by).recent
      @invitations = @family.family_invitations.pending.recent
      render :index, status: :unprocessable_entity
    end
  end

  # Resend invitation
  def resend_invitation
    @invitation = @family.family_invitations.find(params[:invitation_id])
    
    if @invitation.resend!
      redirect_to family_members_path(@family), 
                  notice: "Invitation resent to #{@invitation.email}."
    else
      redirect_to family_members_path(@family), 
                  alert: "Failed to resend invitation."
    end
  end

  # Cancel invitation
  def cancel_invitation
    @invitation = @family.family_invitations.find(params[:invitation_id])
    @invitation.destroy
    
    redirect_to family_members_path(@family), 
                notice: "Invitation to #{@invitation.email} cancelled."
  end

  private

  def set_family
    @family = Family.find(params[:family_id])
  end

  def set_member
    @member = @family.family_memberships.find(params[:id])
  end

  def check_management_permission
    unless @family.user_can_manage?(current_user)
      redirect_to @family, alert: 'You do not have permission to manage family members.'
    end
  end

  def valid_role_change?(new_role)
    return false unless FamilyMembership::ROLES.include?(new_role)
    return false if @member.user == @family.created_by && new_role != 'owner'
    
    true
  end

  def invitation_params
    params.require(:family_invitation).permit(:email, :role, :message)
  end
end
```

### 4. Create Family Invitations Controller
Create `app/controllers/family_invitations_controller.rb`:

```ruby
class FamilyInvitationsController < ApplicationController
  before_action :set_invitation, only: [:show, :accept, :decline]

  def show
    if @invitation.expired?
      render :expired
    elsif @invitation.accepted?
      render :already_accepted
    else
      # Show invitation details
    end
  end

  def accept
    if user_signed_in?
      handle_signed_in_user_acceptance
    else
      # Store invitation token in session and redirect to sign up
      session[:invitation_token] = @invitation.token
      redirect_to new_user_registration_path, 
                  notice: "Please create an account or sign in to accept this invitation."
    end
  end

  def decline
    @invitation.destroy
    redirect_to root_path, notice: "Invitation declined."
  end

  # Handle acceptance after user signs up/in
  def process_pending
    invitation_token = session.delete(:invitation_token)
    return redirect_to root_path unless invitation_token

    invitation = FamilyInvitation.find_by(token: invitation_token)
    return redirect_to root_path unless invitation&.pending?

    if invitation.accept!(current_user)
      redirect_to invitation.family, 
                  notice: "Welcome to #{invitation.family.name}!"
    else
      redirect_to root_path, 
                  alert: "Unable to accept invitation. Please contact the family administrator."
    end
  end

  private

  def set_invitation
    @invitation = FamilyInvitation.find_by(token: params[:token])
    
    unless @invitation
      redirect_to root_path, alert: "Invalid invitation link."
    end
  end

  def handle_signed_in_user_acceptance
    if current_user.email != @invitation.email
      redirect_to family_invitation_path(@invitation.token), 
                  alert: "This invitation is for #{@invitation.email}. Please sign in with that email address."
      return
    end

    if @invitation.accept!(current_user)
      redirect_to @invitation.family, 
                  notice: "Welcome to #{@invitation.family.name}!"
    else
      redirect_to family_invitation_path(@invitation.token), 
                  alert: "Unable to accept invitation."
    end
  end
end
```

### 5. Create Family Invitation Mailer
Create `app/mailers/family_invitation_mailer.rb`:

```ruby
class FamilyInvitationMailer < ApplicationMailer
  default from: 'noreply@familyphotoshare.com'

  def invitation_email(invitation)
    @invitation = invitation
    @family = invitation.family
    @invited_by = invitation.invited_by
    @accept_url = family_invitation_url(token: invitation.token)

    mail(
      to: invitation.email,
      subject: "#{@invited_by.display_name_or_full_name} invited you to join #{@family.name}"
    )
  end

  def reminder_email(invitation)
    @invitation = invitation
    @family = invitation.family
    @invited_by = invitation.invited_by
    @accept_url = family_invitation_url(token: invitation.token)

    mail(
      to: invitation.email,
      subject: "Reminder: Join #{@family.name} on Family Photo Share"
    )
  end
end
```

### 6. Create Email Templates
Create `app/views/family_invitation_mailer/invitation_email.html.erb`:

```erb
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Family Photo Share Invitation</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #007bff; color: white; padding: 20px; text-align: center; }
    .content { background: white; padding: 30px; border: 1px solid #ddd; }
    .button { display: inline-block; padding: 12px 24px; background: #28a745; color: white; text-decoration: none; border-radius: 4px; margin: 20px 0; }
    .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Family Photo Share</h1>
    </div>
    
    <div class="content">
      <h2>You're invited to join <%= @family.name %>!</h2>
      
      <p>Hi there!</p>
      
      <p>
        <strong><%= @invited_by.display_name_or_full_name %></strong> has invited you to join 
        <strong><%= @family.name %></strong> on Family Photo Share.
      </p>
      
      <% if @family.description.present? %>
        <p><em>"<%= @family.description %>"</em></p>
      <% end %>
      
      <% if @invitation.message.present? %>
        <div style="background: #f8f9fa; padding: 15px; border-left: 4px solid #007bff; margin: 20px 0;">
          <strong>Personal message:</strong><br>
          <%= simple_format(@invitation.message) %>
        </div>
      <% end %>
      
      <p>As a <strong><%= @invitation.role.titleize %></strong>, you'll be able to:</p>
      
      <ul>
        <% case @invitation.role %>
        <% when 'owner' %>
          <li>View all family photos</li>
          <li>Upload and edit photos</li>
          <li>Invite and manage family members</li>
          <li>Manage family settings</li>
        <% when 'editor' %>
          <li>View all family photos</li>
          <li>Upload and edit photos</li>
          <li>Invite new family members</li>
        <% when 'viewer' %>
          <li>View all family photos</li>
          <li>Comment on photos</li>
        <% end %>
      </ul>
      
      <div style="text-align: center; margin: 30px 0;">
        <a href="<%= @accept_url %>" class="button">Accept Invitation</a>
      </div>
      
      <p><small>This invitation will expire on <%= @invitation.expires_at.strftime("%B %d, %Y") %>.</small></p>
      
      <p><small>
        If you don't want to join this family, you can safely ignore this email.
        If you have any questions, please reply to this email.
      </small></p>
    </div>
    
    <div class="footer">
      <p>Family Photo Share - Keeping families connected through photos</p>
    </div>
  </div>
</body>
</html>
```

Create `app/views/family_invitation_mailer/invitation_email.text.erb`:

```
You're invited to join <%= @family.name %>!

Hi there!

<%= @invited_by.display_name_or_full_name %> has invited you to join <%= @family.name %> on Family Photo Share.

<% if @family.description.present? %>
About this family: <%= @family.description %>
<% end %>

<% if @invitation.message.present? %>
Personal message from <%= @invited_by.display_name_or_full_name %>:
<%= @invitation.message %>
<% end %>

As a <%= @invitation.role.titleize %>, you'll be able to view and share photos with your family.

To accept this invitation, visit: <%= @accept_url %>

This invitation will expire on <%= @invitation.expires_at.strftime("%B %d, %Y") %>.

If you don't want to join this family, you can safely ignore this email.

---
Family Photo Share - Keeping families connected through photos
```

### 7. Create Member Management Views
Create `app/views/family_members/index.html.erb`:

```erb
<div class="members-header">
  <h1><%= @family.name %> - Members</h1>
  <%= link_to "← Back to Family", @family, class: "btn btn-secondary" %>
</div>

<!-- Current Members -->
<div class="members-section">
  <h2>Current Members (<%= @family.member_count %>)</h2>
  
  <div class="members-table">
    <% @members.each do |membership| %>
      <div class="member-row">
        <div class="member-info">
          <% if membership.user.avatar_url.present? %>
            <%= image_tag membership.user.avatar_url, class: "avatar-medium" %>
          <% else %>
            <div class="avatar-placeholder avatar-medium">
              <%= membership.user.display_name_or_full_name.first.upcase %>
            </div>
          <% end %>
          
          <div class="member-details">
            <strong><%= membership.user.display_name_or_full_name %></strong>
            <small><%= membership.user.email %></small>
            <div class="member-meta">
              Joined <%= membership.joined_at.strftime("%B %Y") %>
              <% if membership.invited_by.present? %>
                • Invited by <%= membership.invited_by.display_name_or_full_name %>
              <% end %>
            </div>
          </div>
        </div>

        <div class="member-role">
          <span class="role-badge role-<%= membership.role %>">
            <%= membership.role.titleize %>
          </span>
        </div>

        <div class="member-actions">
          <% unless membership.user == @family.created_by %>
            <!-- Role Change Dropdown -->
            <%= form_with model: [@family, membership], method: :patch, local: true, class: "role-form" do |f| %>
              <%= f.select :role, options_for_select(
                    FamilyMembership::ROLES.map { |role| [role.titleize, role] },
                    membership.role
                  ), {}, { 
                    class: "form-control form-control-sm", 
                    onchange: "this.form.submit()"
                  } %>
            <% end %>

            <!-- Remove Member -->
            <%= link_to "Remove", family_member_path(@family, membership), 
                        method: :delete,
                        class: "btn btn-sm btn-danger",
                        confirm: "Are you sure you want to remove #{membership.user.display_name_or_full_name} from this family?" %>
          <% else %>
            <span class="creator-badge">Creator</span>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>

<!-- Pending Invitations -->
<% if @invitations.any? %>
  <div class="invitations-section">
    <h2>Pending Invitations (<%= @invitations.count %>)</h2>
    
    <div class="invitations-list">
      <% @invitations.each do |invitation| %>
        <div class="invitation-row">
          <div class="invitation-info">
            <strong><%= invitation.email %></strong>
            <span class="role-badge role-<%= invitation.role %>">
              <%= invitation.role.titleize %>
            </span>
            <div class="invitation-meta">
              Invited by <%= invitation.invited_by.display_name_or_full_name %>
              • Expires <%= invitation.expires_at.strftime("%B %d, %Y") %>
            </div>
          </div>

          <div class="invitation-actions">
            <%= link_to "Resend", resend_invitation_family_members_path(@family, invitation_id: invitation.id),
                        method: :post, class: "btn btn-sm btn-outline" %>
            <%= link_to "Cancel", cancel_invitation_family_members_path(@family, invitation_id: invitation.id),
                        method: :delete, class: "btn btn-sm btn-danger",
                        confirm: "Cancel invitation to #{invitation.email}?" %>
          </div>
        </div>
      <% end %>
    </div>
  </div>
<% end %>

<!-- Invite New Member -->
<div class="invite-section">
  <h2>Invite New Member</h2>
  
  <%= form_with model: [@family, @invitation], url: invite_family_members_path(@family), local: true do |f| %>
    <%= render 'family_invitation_errors', invitation: @invitation %>

    <div class="invite-form">
      <div class="form-row">
        <div class="form-group">
          <%= f.label :email %>
          <%= f.email_field :email, class: "form-control", placeholder: "Enter email address" %>
        </div>

        <div class="form-group">
          <%= f.label :role %>
          <%= f.select :role, options_for_select(
                FamilyMembership::ROLES.map { |role| [role.titleize, role] }, 'viewer'
              ), {}, { class: "form-control" } %>
        </div>
      </div>

      <div class="form-group">
        <%= f.label :message, "Personal message (optional)" %>
        <%= f.text_area :message, class: "form-control", rows: 3,
                        placeholder: "Add a personal message to the invitation..." %>
      </div>

      <div class="form-actions">
        <%= f.submit "Send Invitation", class: "btn btn-primary" %>
      </div>
    </div>
  <% end %>
</div>
```

Create `app/views/family_members/_family_invitation_errors.html.erb`:

```erb
<% if invitation.errors.any? %>
  <div class="error-messages">
    <h4><%= pluralize(invitation.errors.count, "error") %> prohibited this invitation from being sent:</h4>
    <ul>
      <% invitation.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

### 8. Update Routes
Update `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  resources :profiles, only: [:show, :edit, :update]
  resources :photos do
    collection do
      post :bulk_create
    end
  end

  resources :families do
    resources :members, controller: 'family_members', as: 'family_members' do
      collection do
        post :invite
        post :resend_invitation
        delete :cancel_invitation
      end
    end
    
    member do
      post :join
    end
  end

  # Family invitation routes
  get 'invitations/:token', to: 'family_invitations#show', as: 'family_invitation'
  post 'invitations/:token/accept', to: 'family_invitations#accept', as: 'accept_family_invitation'
  delete 'invitations/:token/decline', to: 'family_invitations#decline', as: 'decline_family_invitation'
  post 'invitations/process_pending', to: 'family_invitations#process_pending', as: 'process_pending_invitation'

  root 'families#index'

  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end
```

## Testing Requirements

### 1. Create Invitation Factory
Create `spec/factories/family_invitations.rb`:

```ruby
FactoryBot.define do
  factory :family_invitation do
    association :family
    association :invited_by, factory: :user
    email { Faker::Internet.email }
    role { 'viewer' }
    expires_at { 7.days.from_now }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :accepted do
      accepted_at { 1.day.ago }
    end

    trait :with_message do
      message { Faker::Lorem.paragraph }
    end
  end
end
```

### 2. Create Controller Tests
Create `spec/controllers/family_members_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe FamilyMembersController, type: :controller do
  let(:family) { create(:family) }
  let(:owner) { family.created_by }
  let(:member) { create(:user) }

  before do
    family.add_member(member, role: 'editor')
    sign_in owner
  end

  describe 'POST #invite' do
    let(:valid_params) do
      {
        family_id: family.id,
        family_invitation: {
          email: 'newmember@example.com',
          role: 'viewer',
          message: 'Join our family!'
        }
      }
    end

    it 'creates a new invitation' do
      expect {
        post :invite, params: valid_params
      }.to change(FamilyInvitation, :count).by(1)
    end

    it 'sends invitation email' do
      expect {
        post :invite, params: valid_params
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe 'PATCH #update' do
    let(:membership) { family.family_memberships.find_by(user: member) }

    it 'updates member role' do
      patch :update, params: { family_id: family.id, id: membership.id, role: 'viewer' }
      
      membership.reload
      expect(membership.role).to eq('viewer')
    end
  end

  describe 'DELETE #destroy' do
    let(:membership) { family.family_memberships.find_by(user: member) }

    it 'removes member from family' do
      expect {
        delete :destroy, params: { family_id: family.id, id: membership.id }
      }.to change(family.members, :count).by(-1)
    end
  end
end
```

## Files to Create/Modify

- `db/migrate/xxx_create_family_invitations.rb` - Invitation table
- `app/models/family_invitation.rb` - Invitation model
- `app/controllers/family_members_controller.rb` - Member management
- `app/controllers/family_invitations_controller.rb` - Invitation handling
- `app/mailers/family_invitation_mailer.rb` - Email notifications
- Email templates for invitations
- Member management views
- Routes for member and invitation management

## Deliverables

1. Complete member management system
2. Email invitation workflow
3. Role-based permission changes
4. Background job email processing
5. Comprehensive invitation tracking

## Next Steps

After completing this ticket, you'll move to Phase 5: Albums & Advanced Features, starting with album creation and photo organization.