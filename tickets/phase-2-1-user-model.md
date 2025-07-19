# Phase 2, Ticket 1: User Model and Basic Authentication

**Priority**: High  
**Estimated Time**: 2-3 hours  
**Prerequisites**: Completed Phase 1  

## Objective

Create the User model with Devise authentication, including basic user attributes and email/password authentication setup.

## Acceptance Criteria

- [ ] User model created with Devise
- [ ] Email/password authentication working
- [ ] User registration and login pages functional
- [ ] Basic user profile attributes included
- [ ] Email confirmation enabled
- [ ] Password reset functionality working
- [ ] Proper validations and tests in place

## Technical Requirements

### 1. Install and Configure Devise
```bash
bundle exec rails generate devise:install
```

Follow the setup instructions that Devise provides:

1. Add default URL options to `config/environments/development.rb`:
```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

2. Update `config/environments/test.rb`:
```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

### 2. Generate User Model
```bash
bundle exec rails generate devise User
```

### 3. Customize User Migration
Edit the generated migration file to include additional fields:
```ruby
class DeviseCreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Additional user fields
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :display_name
      t.text :bio
      t.string :phone_number

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable (optional)
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email

      ## Lockable (optional)
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    add_index :users, :unlock_token,         unique: true
  end
end
```

### 4. Configure User Model
Update `app/models/user.rb`:
```ruby
class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable, :lockable

  # Validations
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :display_name, length: { maximum: 50 }
  validates :bio, length: { maximum: 500 }
  validates :phone_number, format: { with: /\A[\+]?[1-9][\d\s\-\(\)]+\z/, message: "Invalid phone format" }, allow_blank: true

  # Callbacks
  before_save :set_display_name

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name_or_full_name
    display_name.presence || full_name
  end

  private

  def set_display_name
    self.display_name = full_name if display_name.blank?
  end
end
```

### 5. Configure Strong Parameters
Update `config/application.rb`:
```ruby
# Allow additional parameters for Devise
config.to_prepare do
  Devise::RegistrationsController.class_eval do
    before_action :configure_permitted_parameters

    private

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone_number])
      devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :display_name, :bio, :phone_number])
    end
  end
end
```

### 6. Generate Devise Views
```bash
bundle exec rails generate devise:views
```

### 7. Customize Registration Form
Update `app/views/devise/registrations/new.html.erb`:
```erb
<h2>Sign up</h2>

<%= form_for(resource, as: resource_name, url: registration_path(resource_name)) do |f| %>
  <%= render "devise/shared/error_messages", resource: resource %>

  <div class="field">
    <%= f.label :first_name %><br />
    <%= f.text_field :first_name, autofocus: true, autocomplete: "given-name" %>
  </div>

  <div class="field">
    <%= f.label :last_name %><br />
    <%= f.text_field :last_name, autocomplete: "family-name" %>
  </div>

  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autocomplete: "email" %>
  </div>

  <div class="field">
    <%= f.label :phone_number, "Phone Number (Optional)" %><br />
    <%= f.telephone_field :phone_number, autocomplete: "tel" %>
  </div>

  <div class="field">
    <%= f.label :password %>
    <% if @minimum_password_length %>
    <em>(<%= @minimum_password_length %> characters minimum)</em>
    <% end %><br />
    <%= f.password_field :password, autocomplete: "new-password" %>
  </div>

  <div class="field">
    <%= f.label :password_confirmation %><br />
    <%= f.password_field :password_confirmation, autocomplete: "new-password" %>
  </div>

  <div class="actions">
    <%= f.submit "Sign up" %>
  </div>
<% end %>

<%= render "devise/shared/links" %>
```

### 8. Configure Mailer for Development
Update `config/environments/development.rb`:
```ruby
# Email configuration for development
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'localhost',
  port: 1025,
  domain: 'localhost'
}
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
```

## Testing Requirements

### 1. Create User Factory
Create `spec/factories/users.rb`:
```ruby
FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_bio do
      bio { Faker::Lorem.paragraph(sentence_count: 2) }
    end

    trait :with_phone do
      phone_number { Faker::PhoneNumber.phone_number }
    end
  end
end
```

### 2. Create User Model Tests
Create `spec/models/user_spec.rb`:
```ruby
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_length_of(:first_name).is_at_most(50) }
    it { should validate_length_of(:last_name).is_at_most(50) }
    it { should validate_length_of(:display_name).is_at_most(50) }
    it { should validate_length_of(:bio).is_at_most(500) }
  end

  describe 'methods' do
    let(:user) { create(:user, first_name: 'John', last_name: 'Doe') }

    describe '#full_name' do
      it 'returns the full name' do
        expect(user.full_name).to eq('John Doe')
      end
    end

    describe '#display_name_or_full_name' do
      context 'when display_name is present' do
        before { user.update(display_name: 'Johnny') }

        it 'returns the display name' do
          expect(user.display_name_or_full_name).to eq('Johnny')
        end
      end

      context 'when display_name is blank' do
        it 'returns the full name' do
          expect(user.display_name_or_full_name).to eq('John Doe')
        end
      end
    end
  end

  describe 'callbacks' do
    it 'sets display_name to full_name if blank' do
      user = create(:user, first_name: 'Jane', last_name: 'Smith', display_name: '')
      expect(user.display_name).to eq('Jane Smith')
    end
  end
end
```

### 3. Create Feature Tests
Create `spec/features/user_authentication_spec.rb`:
```ruby
require 'rails_helper'

RSpec.feature 'User Authentication', type: :feature do
  scenario 'User signs up successfully' do
    visit new_user_registration_path

    fill_in 'First name', with: 'John'
    fill_in 'Last name', with: 'Doe'
    fill_in 'Email', with: 'john@example.com'
    fill_in 'Password', with: 'password123'
    fill_in 'Password confirmation', with: 'password123'

    click_button 'Sign up'

    expect(page).to have_content('A message with a confirmation link has been sent')
  end

  scenario 'User signs in successfully' do
    user = create(:user, email: 'john@example.com')

    visit new_user_session_path

    fill_in 'Email', with: 'john@example.com'
    fill_in 'Password', with: 'password123'

    click_button 'Log in'

    expect(page).to have_content('Signed in successfully')
  end
end
```

## Files to Create/Modify

- `app/models/user.rb` - User model with validations
- `db/migrate/xxx_devise_create_users.rb` - User table migration
- `config/environments/development.rb` - Mailer configuration
- `config/application.rb` - Strong parameters
- `app/views/devise/registrations/new.html.erb` - Registration form
- `spec/factories/users.rb` - User factory
- `spec/models/user_spec.rb` - User model tests
- `spec/features/user_authentication_spec.rb` - Authentication feature tests

## Deliverables

1. Functional user registration and login system
2. Email confirmation workflow
3. Password reset functionality
4. Comprehensive test coverage
5. Custom user attributes (name, bio, phone)

## Notes for Junior Developer

- Devise is a powerful authentication gem that handles most auth concerns
- Email confirmation prevents spam registrations
- Strong parameters ensure only allowed attributes can be mass-assigned
- Factory Bot creates test data more flexibly than fixtures
- Feature tests verify the complete user workflow

## Validation Steps

1. Run migrations: `rails db:migrate`
2. Run tests: `bundle exec rspec spec/models/user_spec.rb`
3. Start server and visit `/users/sign_up`
4. Register a new user and check for confirmation email
5. Test login/logout functionality
6. Run full test suite: `bundle exec rspec`

## Next Steps

After completing this ticket, you'll move to Phase 2, Ticket 2: Google OAuth Integration.