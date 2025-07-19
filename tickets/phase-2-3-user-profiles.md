# Phase 2, Ticket 3: User Profiles and Settings

**Priority**: Medium  
**Estimated Time**: 1-2 hours  
**Prerequisites**: Completed Phase 2, Ticket 2  

## Objective

Create user profile pages and account settings functionality, allowing users to view and edit their profile information.

## Acceptance Criteria

- [ ] User profile page displays user information
- [ ] Account settings page allows editing profile
- [ ] Avatar/profile image support (preparation for Active Storage)
- [ ] Profile validation and error handling
- [ ] Navigation includes profile links
- [ ] Tests for profile functionality

## Technical Requirements

### 1. Create Profiles Controller
Create `app/controllers/profiles_controller.rb`:

```ruby
class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update]

  def show
    # Profile view - can view any user's public profile
  end

  def edit
    # Only allow editing own profile
    redirect_to root_path unless @user == current_user
  end

  def update
    if @user.update(profile_params)
      redirect_to profile_path(@user), notice: 'Profile updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :display_name, :bio, :phone_number)
  end
end
```

### 2. Create Profile Views
Create `app/views/profiles/show.html.erb`:

```erb
<div class="profile-header">
  <div class="profile-avatar">
    <% if @user.avatar_url.present? %>
      <%= image_tag @user.avatar_url, alt: @user.display_name_or_full_name, class: "avatar-large" %>
    <% else %>
      <div class="avatar-placeholder avatar-large">
        <%= @user.display_name_or_full_name.first.upcase %>
      </div>
    <% end %>
  </div>

  <div class="profile-info">
    <h1><%= @user.display_name_or_full_name %></h1>
    
    <% if @user.bio.present? %>
      <p class="bio"><%= simple_format(@user.bio) %></p>
    <% end %>

    <div class="profile-meta">
      <p><strong>Member since:</strong> <%= @user.created_at.strftime("%B %Y") %></p>
      
      <% if @user.phone_number.present? && @user == current_user %>
        <p><strong>Phone:</strong> <%= @user.phone_number %></p>
      <% end %>
    </div>

    <% if @user == current_user %>
      <div class="profile-actions">
        <%= link_to "Edit Profile", edit_profile_path(@user), class: "btn btn-primary" %>
        <%= link_to "Account Settings", edit_user_registration_path, class: "btn btn-secondary" %>
      </div>
    <% end %>
  </div>
</div>

<div class="profile-content">
  <!-- Future: User's albums and photos will go here -->
  <div class="placeholder-content">
    <h3>Albums</h3>
    <p>Photo albums will appear here in a future update.</p>
  </div>
</div>
```

Create `app/views/profiles/edit.html.erb`:

```erb
<h1>Edit Profile</h1>

<%= form_with model: @user, url: profile_path(@user), method: :patch, local: true do |f| %>
  <% if @user.errors.any? %>
    <div class="error-messages">
      <h4><%= pluralize(@user.errors.count, "error") %> prohibited this profile from being saved:</h4>
      <ul>
        <% @user.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="form-group">
    <%= f.label :first_name %>
    <%= f.text_field :first_name, class: "form-control" %>
  </div>

  <div class="form-group">
    <%= f.label :last_name %>
    <%= f.text_field :last_name, class: "form-control" %>
  </div>

  <div class="form-group">
    <%= f.label :display_name, "Display Name (optional)" %>
    <%= f.text_field :display_name, class: "form-control", placeholder: "Leave blank to use full name" %>
  </div>

  <div class="form-group">
    <%= f.label :bio, "Bio (optional)" %>
    <%= f.text_area :bio, class: "form-control", rows: 4, placeholder: "Tell others about yourself..." %>
  </div>

  <div class="form-group">
    <%= f.label :phone_number, "Phone Number (optional)" %>
    <%= f.telephone_field :phone_number, class: "form-control" %>
  </div>

  <div class="form-actions">
    <%= f.submit "Update Profile", class: "btn btn-primary" %>
    <%= link_to "Cancel", profile_path(@user), class: "btn btn-secondary" %>
  </div>
<% end %>
```

### 3. Update Routes
Update `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }

  # Profile routes
  resources :profiles, only: [:show, :edit, :update]

  # Add root route for now
  root 'profiles#show', id: -> { User.first&.id || 1 }

  # Sidekiq web interface
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end
```

### 4. Update Application Layout
Create `app/views/layouts/application.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>Family Photo Share</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <header class="navbar">
      <div class="navbar-container">
        <%= link_to "Family Photo Share", root_path, class: "navbar-brand" %>

        <nav class="navbar-nav">
          <% if user_signed_in? %>
            <div class="nav-item dropdown">
              <a class="nav-link dropdown-toggle" href="#" data-toggle="dropdown">
                <% if current_user.avatar_url.present? %>
                  <%= image_tag current_user.avatar_url, class: "avatar-small" %>
                <% else %>
                  <span class="avatar-placeholder avatar-small">
                    <%= current_user.display_name_or_full_name.first.upcase %>
                  </span>
                <% end %>
                <%= current_user.display_name_or_full_name %>
              </a>
              <div class="dropdown-menu">
                <%= link_to "My Profile", profile_path(current_user), class: "dropdown-item" %>
                <%= link_to "Account Settings", edit_user_registration_path, class: "dropdown-item" %>
                <div class="dropdown-divider"></div>
                <%= link_to "Sign Out", destroy_user_session_path, method: :delete, class: "dropdown-item" %>
              </div>
            </div>
          <% else %>
            <%= link_to "Sign In", new_user_session_path, class: "nav-link" %>
            <%= link_to "Sign Up", new_user_registration_path, class: "nav-link" %>
          <% end %>
        </nav>
      </div>
    </header>

    <main class="main-content">
      <% flash.each do |type, message| %>
        <div class="alert alert-<%= type == 'notice' ? 'success' : 'danger' %>">
          <%= message %>
        </div>
      <% end %>

      <%= yield %>
    </main>

    <footer class="footer">
      <p>&copy; <%= Date.current.year %> Family Photo Share</p>
    </footer>
  </body>
</html>
```

### 5. Add Basic Styling
Create `app/assets/stylesheets/application.css`:

```css
/* Application Styles */

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  margin: 0;
  padding: 0;
  background-color: #f8f9fa;
}

/* Navigation */
.navbar {
  background-color: #ffffff;
  border-bottom: 1px solid #dee2e6;
  padding: 1rem 0;
}

.navbar-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.navbar-brand {
  font-size: 1.5rem;
  font-weight: bold;
  color: #007bff;
  text-decoration: none;
}

.navbar-nav {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.nav-link {
  color: #6c757d;
  text-decoration: none;
  padding: 0.5rem 1rem;
}

.nav-link:hover {
  color: #007bff;
}

/* Avatar styles */
.avatar-small {
  width: 32px;
  height: 32px;
  border-radius: 50%;
}

.avatar-large {
  width: 120px;
  height: 120px;
  border-radius: 50%;
}

.avatar-placeholder {
  background-color: #6c757d;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
}

.avatar-placeholder.avatar-small {
  font-size: 14px;
}

.avatar-placeholder.avatar-large {
  font-size: 48px;
}

/* Main content */
.main-content {
  max-width: 1200px;
  margin: 2rem auto;
  padding: 0 1rem;
  min-height: calc(100vh - 200px);
}

/* Profile styles */
.profile-header {
  display: flex;
  gap: 2rem;
  margin-bottom: 2rem;
  background: white;
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.profile-info h1 {
  margin: 0 0 1rem 0;
  color: #333;
}

.profile-meta {
  color: #6c757d;
  margin: 1rem 0;
}

.profile-actions {
  margin-top: 1rem;
}

/* Forms */
.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: bold;
}

.form-control {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ced4da;
  border-radius: 4px;
  font-size: 1rem;
}

.form-control:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 0.2rem rgba(0,123,255,0.25);
}

/* Buttons */
.btn {
  display: inline-block;
  padding: 0.75rem 1.5rem;
  margin-right: 0.5rem;
  border: none;
  border-radius: 4px;
  text-decoration: none;
  cursor: pointer;
  font-size: 1rem;
}

.btn-primary {
  background-color: #007bff;
  color: white;
}

.btn-secondary {
  background-color: #6c757d;
  color: white;
}

.btn:hover {
  opacity: 0.9;
}

/* Alerts */
.alert {
  padding: 1rem;
  margin-bottom: 1rem;
  border-radius: 4px;
}

.alert-success {
  background-color: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.alert-danger {
  background-color: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

/* Footer */
.footer {
  background-color: #f8f9fa;
  text-align: center;
  padding: 2rem;
  border-top: 1px solid #dee2e6;
  color: #6c757d;
}
```

## Testing Requirements

### 1. Create Profile Controller Tests
Create `spec/controllers/profiles_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ProfilesController, type: :controller do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe 'GET #show' do
    context 'when signed in' do
      before { sign_in user }

      it 'displays the user profile' do
        get :show, params: { id: user.id }
        expect(response).to be_successful
        expect(assigns(:user)).to eq(user)
      end
    end

    context 'when not signed in' do
      it 'redirects to sign in' do
        get :show, params: { id: user.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #edit' do
    before { sign_in user }

    context 'editing own profile' do
      it 'allows editing' do
        get :edit, params: { id: user.id }
        expect(response).to be_successful
      end
    end

    context 'editing other user profile' do
      it 'redirects to root' do
        get :edit, params: { id: other_user.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PATCH #update' do
    before { sign_in user }

    context 'with valid parameters' do
      let(:valid_params) { { user: { first_name: 'Updated', bio: 'New bio' } } }

      it 'updates the user' do
        patch :update, params: { id: user.id }.merge(valid_params)
        user.reload
        expect(user.first_name).to eq('Updated')
        expect(user.bio).to eq('New bio')
      end

      it 'redirects to profile' do
        patch :update, params: { id: user.id }.merge(valid_params)
        expect(response).to redirect_to(profile_path(user))
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { { user: { first_name: '' } } }

      it 'renders edit template' do
        patch :update, params: { id: user.id }.merge(invalid_params)
        expect(response).to render_template(:edit)
      end
    end
  end
end
```

### 2. Create Feature Tests
Create `spec/features/user_profiles_spec.rb`:

```ruby
require 'rails_helper'

RSpec.feature 'User Profiles', type: :feature do
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe', bio: 'Test bio') }

  before { sign_in user }

  scenario 'User views their own profile' do
    visit profile_path(user)

    expect(page).to have_content('John Doe')
    expect(page).to have_content('Test bio')
    expect(page).to have_link('Edit Profile')
  end

  scenario 'User edits their profile' do
    visit edit_profile_path(user)

    fill_in 'First name', with: 'Jane'
    fill_in 'Bio', with: 'Updated bio'

    click_button 'Update Profile'

    expect(page).to have_content('Profile updated successfully')
    expect(page).to have_content('Jane Doe')
    expect(page).to have_content('Updated bio')
  end

  scenario 'User sees validation errors' do
    visit edit_profile_path(user)

    fill_in 'First name', with: ''

    click_button 'Update Profile'

    expect(page).to have_content("First name can't be blank")
  end
end
```

## Files to Create/Modify

- `app/controllers/profiles_controller.rb` - Profile management
- `app/views/profiles/show.html.erb` - Profile display
- `app/views/profiles/edit.html.erb` - Profile editing
- `app/views/layouts/application.html.erb` - Application layout
- `app/assets/stylesheets/application.css` - Basic styling
- `config/routes.rb` - Profile routes
- `spec/controllers/profiles_controller_spec.rb` - Controller tests
- `spec/features/user_profiles_spec.rb` - Feature tests

## Deliverables

1. User profile viewing functionality
2. Profile editing with validation
3. Basic application layout and navigation
4. Responsive design foundation
5. Comprehensive test coverage

## Notes for Junior Developer

- The profile system is the foundation for user interaction
- Avatar support is prepared but will be fully implemented with Active Storage
- The layout includes navigation that will be used throughout the app
- CSS is kept simple and will be enhanced in later phases
- Tests use the `sign_in` helper method (you may need to add Devise test helpers)

## Validation Steps

1. Start server and visit a user profile URL
2. Test profile editing functionality
3. Verify navigation links work correctly
4. Check responsive behavior on different screen sizes
5. Run test suite: `bundle exec rspec spec/controllers/profiles_controller_spec.rb`

## Next Steps

After completing this ticket, you'll move to Phase 3: Core Photo Features, starting with Active Storage setup.