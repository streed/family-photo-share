# Phase 2, Ticket 2: Google OAuth Integration [REMOVED]

**Status**: REMOVED - Google OAuth integration has been removed from the application  
**Priority**: N/A  
**Estimated Time**: N/A  
**Prerequisites**: N/A  

## Objective

~~Integrate Google OAuth authentication to allow users to sign up and log in using their Google accounts, alongside the existing email/password authentication.~~

**This feature has been removed from the application. Users can only authenticate using email/password through Devise.**

## Acceptance Criteria

- [ ] Google OAuth sign-up and sign-in functionality working
- [ ] Users can choose between email/password or Google authentication
- [ ] Google user data properly mapped to User model
- [ ] Existing email/password users can link Google accounts
- [ ] Error handling for OAuth failures
- [ ] Tests covering OAuth workflows

## Technical Requirements

### 1. Configure OmniAuth for Google
The gems are already in the Gemfile from Phase 1. Update `config/initializers/devise.rb`:

```ruby
# Add this configuration block
Devise.setup do |config|
  # ... existing configuration ...

  # OmniAuth configuration
  config.omniauth :google_oauth2, 
    ENV['GOOGLE_CLIENT_ID'], 
    ENV['GOOGLE_CLIENT_SECRET'],
    {
      scope: 'email,profile',
      prompt: 'select_account',
      image_aspect_ratio: 'square',
      image_size: 50
    }
end
```

### 2. Update User Model for OAuth
Update `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  # Add :omniauthable to devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable, :lockable, :omniauthable,
         omniauth_providers: [:google_oauth2]

  # Add OAuth fields validation
  validates :provider, presence: true, if: :uid?
  validates :uid, presence: true, if: :provider?

  # ... existing validations and methods ...

  # OAuth class method
  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.first_name = auth.info.first_name || auth.info.name.split(' ').first
      user.last_name = auth.info.last_name || auth.info.name.split(' ').last
      user.provider = auth.provider
      user.uid = auth.uid
      user.confirmed_at = Time.current # Auto-confirm OAuth users
      
      # Set profile image URL if available
      user.avatar_url = auth.info.image if auth.info.image
    end
  end

  # Check if user signed up via OAuth
  def oauth_user?
    provider.present? && uid.present?
  end

  # Check if user can change password (not OAuth-only users)
  def password_required?
    super && !oauth_user?
  end
end
```

### 3. Add OAuth Fields to User Migration
Create a new migration:

```bash
bundle exec rails generate migration AddOmniauthToUsers provider:string uid:string avatar_url:string
```

Edit the migration:
```ruby
class AddOmniauthToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :avatar_url, :string

    add_index :users, [:provider, :uid], unique: true
  end
end
```

### 4. Create OmniAuth Callbacks Controller
Create `app/controllers/users/omniauth_callbacks_controller.rb`:

```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      flash[:notice] = I18n.t 'devise.omniauth_callbacks.success', kind: 'Google'
      sign_in_and_redirect @user, event: :authentication
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except('extra')
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to root_path, alert: 'Authentication failed. Please try again.'
  end
end
```

### 5. Update Routes
Update `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Update devise_for to use custom controllers
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  # ... existing routes ...
end
```

### 6. Update Sign-in/Sign-up Views
Update `app/views/devise/sessions/new.html.erb`:

```erb
<h2>Log in</h2>

<%= form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>
  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="field">
    <%= f.label :password %><br />
    <%= f.password_field :password, autocomplete: "current-password" %>
  </div>

  <% if devise_mapping.rememberable? %>
    <div class="field">
      <%= f.check_box :remember_me %>
      <%= f.label :remember_me %>
    </div>
  <% end %>

  <div class="actions">
    <%= f.submit "Log in" %>
  </div>
<% end %>

<div class="oauth-options">
  <p>Or sign in with:</p>
  <%= button_to "Sign in with Google", 
      user_google_oauth2_omniauth_authorize_path, 
      method: :post, 
      class: "btn btn-google" %>
</div>

<%= render "devise/shared/links" %>
```

Update `app/views/devise/registrations/new.html.erb` to add Google sign-up option:

```erb
<!-- Add this after the existing form and before the links -->
<div class="oauth-options">
  <p>Or sign up with:</p>
  <%= button_to "Sign up with Google", 
      user_google_oauth2_omniauth_authorize_path, 
      method: :post, 
      class: "btn btn-google" %>
</div>
```

### 7. Update Strong Parameters
Update the strong parameters in `config/application.rb`:

```ruby
config.to_prepare do
  Devise::RegistrationsController.class_eval do
    before_action :configure_permitted_parameters

    private

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone_number, :provider, :uid])
      devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :display_name, :bio, :phone_number])
    end
  end
end
```

### 8. Environment Variables
Update `.env.example`:

```bash
# OAuth credentials
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
```

## Testing Requirements

### 1. Update User Factory
Update `spec/factories/users.rb`:

```ruby
FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    confirmed_at { Time.current }

    trait :oauth_user do
      provider { 'google_oauth2' }
      uid { Faker::Number.number(digits: 10).to_s }
      password { nil }
      password_confirmation { nil }
    end

    # ... existing traits ...
  end
end
```

### 2. Create OAuth Tests
Create `spec/models/user_oauth_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'OAuth functionality' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: '123456789',
        info: {
          email: 'test@gmail.com',
          first_name: 'John',
          last_name: 'Doe',
          name: 'John Doe',
          image: 'https://lh3.googleusercontent.com/a/default-user'
        }
      })
    end

    describe '.from_omniauth' do
      context 'when user does not exist' do
        it 'creates a new user' do
          expect {
            User.from_omniauth(auth_hash)
          }.to change(User, :count).by(1)
        end

        it 'sets user attributes correctly' do
          user = User.from_omniauth(auth_hash)
          
          expect(user.email).to eq('test@gmail.com')
          expect(user.first_name).to eq('John')
          expect(user.last_name).to eq('Doe')
          expect(user.provider).to eq('google_oauth2')
          expect(user.uid).to eq('123456789')
          expect(user.confirmed_at).to be_present
        end
      end

      context 'when user already exists' do
        let!(:existing_user) { create(:user, email: 'test@gmail.com') }

        it 'does not create a new user' do
          expect {
            User.from_omniauth(auth_hash)
          }.not_to change(User, :count)
        end

        it 'returns the existing user' do
          user = User.from_omniauth(auth_hash)
          expect(user).to eq(existing_user)
        end
      end
    end

    describe '#oauth_user?' do
      it 'returns true for OAuth users' do
        user = create(:user, :oauth_user)
        expect(user.oauth_user?).to be true
      end

      it 'returns false for regular users' do
        user = create(:user)
        expect(user.oauth_user?).to be false
      end
    end
  end
end
```

### 3. Create Controller Tests
Create `spec/controllers/users/omniauth_callbacks_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Users::OmniauthCallbacksController, type: :controller do
  before do
    request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe 'GET #google_oauth2' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: '123456789',
        info: {
          email: 'test@gmail.com',
          first_name: 'John',
          last_name: 'Doe',
          name: 'John Doe'
        }
      })
    end

    before do
      request.env["omniauth.auth"] = auth_hash
    end

    context 'when user creation is successful' do
      it 'creates a new user and signs them in' do
        expect {
          get :google_oauth2
        }.to change(User, :count).by(1)

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include('Google')
      end
    end

    context 'when user creation fails' do
      before do
        allow(User).to receive(:from_omniauth).and_return(double(persisted?: false, errors: double(full_messages: ['Error'])))
      end

      it 'redirects to registration with error' do
        get :google_oauth2
        expect(response).to redirect_to(new_user_registration_url)
        expect(flash[:alert]).to include('Error')
      end
    end
  end
end
```

## Files to Create/Modify

- `config/initializers/devise.rb` - OmniAuth configuration
- `app/models/user.rb` - OAuth methods and validations
- `db/migrate/xxx_add_omniauth_to_users.rb` - OAuth fields migration
- `app/controllers/users/omniauth_callbacks_controller.rb` - OAuth callbacks
- `config/routes.rb` - OAuth routes
- `app/views/devise/sessions/new.html.erb` - Google sign-in button
- `app/views/devise/registrations/new.html.erb` - Google sign-up button
- `spec/models/user_oauth_spec.rb` - OAuth model tests
- `spec/controllers/users/omniauth_callbacks_controller_spec.rb` - Controller tests

## Deliverables

1. Functional Google OAuth authentication
2. Seamless integration with existing email/password auth
3. Proper user data mapping from Google
4. Comprehensive test coverage for OAuth flows
5. Updated UI with Google sign-in/sign-up options

## Notes for Junior Developer

- You'll need to create a Google OAuth application in Google Cloud Console
- The `from_omniauth` method handles both new user creation and existing user lookup
- OAuth users are automatically confirmed since Google verifies email addresses
- The callback controller handles the OAuth response from Google
- Store OAuth credentials in environment variables, never in code

## Google OAuth Setup Instructions

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google+ API
4. Go to Credentials → Create OAuth 2.0 Client ID
5. Set authorized redirect URI: `http://localhost:3000/users/auth/google_oauth2/callback`
6. Copy Client ID and Secret to `.env` file

## Validation Steps

1. Run migrations: `rails db:migrate`
2. Set up Google OAuth credentials in `.env`
3. Start server and visit sign-in page
4. Test Google sign-in flow
5. Verify user creation in database
6. Test existing user Google account linking
7. Run test suite: `bundle exec rspec`

## Next Steps

After completing this ticket, you'll move to Phase 2, Ticket 3: User Profiles and Settings.