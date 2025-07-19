# Phase 5, Ticket 2: Album Views and Photo Management Interface

**Priority**: High  
**Estimated Time**: 4-5 hours  
**Prerequisites**: Completed Phase 5, Ticket 1  

## Objective

Create comprehensive album views with photo management interface, including drag-and-drop photo organization, cover photo selection, and passcode-protected album access.

## Acceptance Criteria

- [ ] Album listing page with cover photos and stats
- [ ] Album detail view with photo grid
- [ ] Album creation and editing forms
- [ ] Photo management within albums (add/remove/reorder)
- [ ] Drag-and-drop photo reordering
- [ ] Cover photo selection interface
- [ ] Passcode entry form for protected albums
- [ ] Responsive design for mobile and desktop
- [ ] JavaScript-enhanced user interactions

## Technical Requirements

### 1. Create Album Views

Create `app/views/albums/index.html.erb`:

```erb
<div class="albums-header">
  <h1><%= @family.name %> - Albums</h1>
  <div class="albums-actions">
    <%= link_to "← Back to Family", @family, class: "btn btn-secondary" %>
    <% if @can_create_albums %>
      <%= link_to "Create Album", new_family_album_path(@family), class: "btn btn-primary" %>
    <% end %>
  </div>
</div>

<% if @albums.any? %>
  <div class="albums-grid">
    <% @albums.each do |album| %>
      <div class="album-card">
        <%= link_to [@album.family, album], class: "album-link" do %>
          <div class="album-cover">
            <% if album.cover_photo_or_first %>
              <%= photo_tag(album.cover_photo_or_first, :medium, class: "cover-image") %>
            <% else %>
              <div class="no-photos-placeholder">
                <i class="album-icon">📁</i>
                <span>No photos</span>
              </div>
            <% end %>
            
            <div class="album-overlay">
              <div class="album-stats">
                <span class="photo-count">
                  <i class="icon">📷</i> <%= album.photo_count %>
                </span>
                <% unless album.family? %>
                  <span class="privacy-badge privacy-<%= album.privacy_level %>">
                    <% case album.privacy_level %>
                    <% when 'private' %>
                      <i class="icon">🔒</i> Private
                    <% when 'passcode_protected' %>
                      <i class="icon">🔐</i> Protected
                    <% end %>
                  </span>
                <% end %>
              </div>
            </div>
          </div>

          <div class="album-info">
            <h3 class="album-title"><%= album.title %></h3>
            <% if album.description.present? %>
              <p class="album-description">
                <%= truncate(album.description, length: 80) %>
              </p>
            <% end %>
            
            <div class="album-meta">
              <small>
                by <%= album.created_by.display_name_or_full_name %> •
                <%= time_ago_in_words(album.created_at) %> ago
              </small>
            </div>
          </div>
        <% end %>

        <% if album.editable_by?(current_user) %>
          <div class="album-actions">
            <%= link_to "Edit", edit_family_album_path(@family, album), 
                        class: "btn btn-sm btn-secondary" %>
            <%= link_to "Delete", family_album_path(@family, album), 
                        method: :delete,
                        class: "btn btn-sm btn-danger",
                        confirm: "Are you sure you want to delete this album and remove all photos from it?" %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
<% else %>
  <div class="empty-state">
    <h2>No albums yet</h2>
    <p>Create your first album to organize your family photos!</p>
    <% if @can_create_albums %>
      <%= link_to "Create First Album", new_family_album_path(@family), 
                  class: "btn btn-primary btn-lg" %>
    <% end %>
  </div>
<% end %>
```

Create `app/views/albums/show.html.erb`:

```erb
<div class="album-header">
  <div class="album-title-section">
    <h1><%= @album.title %></h1>
    <% if @album.description.present? %>
      <p class="album-description"><%= simple_format(@album.description) %></p>
    <% end %>
    
    <div class="album-meta">
      <span class="creator">
        Created by <%= @album.created_by.display_name_or_full_name %>
      </span>
      <span class="date">
        <%= @album.created_at.strftime("%B %d, %Y") %>
      </span>
      <span class="photo-count">
        <%= @album.photo_count %> #{'photo'.pluralize(@album.photo_count)}
      </span>
      
      <% unless @album.family? %>
        <span class="privacy-badge privacy-<%= @album.privacy_level %>">
          <% case @album.privacy_level %>
          <% when 'private' %>
            <i class="icon">🔒</i> Private
          <% when 'passcode_protected' %>
            <i class="icon">🔐</i> Passcode Protected
          <% end %>
        </span>
      <% end %>
    </div>
  </div>

  <div class="album-actions">
    <%= link_to "← Back to Albums", family_albums_path(@album.family), 
                class: "btn btn-secondary" %>
    
    <% if @can_edit %>
      <div class="edit-actions">
        <%= link_to "Edit Album", edit_family_album_path(@album.family, @album), 
                    class: "btn btn-primary" %>
        <button id="manage-photos-btn" class="btn btn-success">
          Manage Photos
        </button>
        <button id="reorder-photos-btn" class="btn btn-outline" style="display: none;">
          Reorder Photos
        </button>
      </div>
    <% end %>
  </div>
</div>

<!-- Photo Management Panel (hidden by default) -->
<% if @can_edit %>
  <div id="photo-management-panel" class="photo-management-panel" style="display: none;">
    <div class="panel-header">
      <h3>Add Photos to Album</h3>
      <button id="close-management-btn" class="btn btn-sm btn-secondary">
        Close
      </button>
    </div>
    
    <% if @available_photos.any? %>
      <%= form_with url: add_photos_family_album_path(@album.family, @album), 
                    method: :patch, local: true, id: "add-photos-form" do |f| %>
        <div class="available-photos-grid">
          <% @available_photos.each do |photo| %>
            <div class="available-photo">
              <label class="photo-checkbox-label">
                <%= check_box_tag "photo_ids[]", photo.id, false, 
                                  class: "photo-checkbox" %>
                <%= photo_tag(photo, :thumbnail, class: "selectable-photo") %>
                <div class="photo-overlay">
                  <span class="checkbox-indicator">✓</span>
                </div>
              </label>
              <div class="photo-title">
                <%= truncate(photo.title, length: 20) %>
              </div>
            </div>
          <% end %>
        </div>
        
        <div class="panel-actions">
          <%= submit "Add Selected Photos", class: "btn btn-primary", 
                     id: "add-photos-submit", disabled: true %>
        </div>
      <% end %>
    <% else %>
      <div class="no-available-photos">
        <p>All your photos are already in this album!</p>
        <%= link_to "Upload new photos", new_photo_path, class: "btn btn-primary" %>
      </div>
    <% end %>
  </div>
<% end %>

<!-- Album Photos Grid -->
<div class="album-photos-container">
  <% if @album_photos.any? %>
    <div class="album-photos-grid" id="album-photos-grid" 
         data-album-id="<%= @album.id %>" 
         data-can-edit="<%= @can_edit %>">
      <% @album_photos.each do |album_photo| %>
        <div class="album-photo-item" data-photo-id="<%= album_photo.photo.id %>">
          <%= link_to photo_path(album_photo.photo), class: "photo-link" do %>
            <%= photo_tag(album_photo.photo, :medium, class: "album-photo-image") %>
          <% end %>
          
          <% if @can_edit %>
            <div class="photo-controls">
              <button class="set-cover-btn <%= 'active' if @album.cover_photo == album_photo.photo %>"
                      data-photo-id="<%= album_photo.photo.id %>"
                      title="Set as cover photo">
                <i class="icon">⭐</i>
              </button>
              
              <button class="remove-photo-btn" 
                      data-photo-id="<%= album_photo.photo.id %>"
                      title="Remove from album">
                <i class="icon">🗑️</i>
              </button>
            </div>
            
            <div class="drag-handle" title="Drag to reorder">
              <i class="icon">≡</i>
            </div>
          <% end %>
          
          <div class="photo-info">
            <h4 class="photo-title">
              <%= truncate(album_photo.photo.title, length: 30) %>
            </h4>
            <% if album_photo.caption.present? %>
              <p class="photo-caption">
                <%= truncate(album_photo.caption, length: 50) %>
              </p>
            <% end %>
            <small class="added-by">
              Added by <%= album_photo.added_by.display_name_or_full_name %>
            </small>
          </div>
        </div>
      <% end %>
    </div>
  <% else %>
    <div class="empty-album">
      <div class="empty-album-content">
        <i class="empty-icon">📷</i>
        <h3>This album is empty</h3>
        <p>Start adding photos to bring this album to life!</p>
        
        <% if @can_edit %>
          <button id="add-first-photo-btn" class="btn btn-primary btn-lg">
            Add Photos
          </button>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

Create `app/views/albums/new.html.erb`:

```erb
<h1>Create New Album</h1>

<%= form_with model: [@family, @album], local: true, class: "album-form" do |f| %>
  <%= render 'form_errors', album: @album %>

  <div class="form-group">
    <%= f.label :title %>
    <%= f.text_field :title, class: "form-control", 
                     placeholder: "Enter album title", autofocus: true %>
  </div>

  <div class="form-group">
    <%= f.label :description, "Description (optional)" %>
    <%= f.text_area :description, class: "form-control", rows: 3,
                    placeholder: "What's this album about?" %>
  </div>

  <div class="form-group">
    <%= f.label :privacy_level, "Who can see this album?" %>
    <div class="privacy-options">
      <% Album::PRIVACY_LEVELS.each do |level| %>
        <label class="privacy-option">
          <%= f.radio_button :privacy_level, level, 
                             class: "privacy-radio", 
                             checked: level == 'family' %>
          <div class="privacy-content">
            <strong>
              <% case level %>
              <% when 'family' %>
                <i class="icon">👥</i> Family Members
              <% when 'private' %>
                <i class="icon">🔒</i> Private (Only me)
              <% when 'passcode_protected' %>
                <i class="icon">🔐</i> Passcode Protected
              <% end %>
            </strong>
            <p>
              <% case level %>
              <% when 'family' %>
                All family members can view this album
              <% when 'private' %>
                Only you can see this album
              <% when 'passcode_protected' %>
                Anyone with the passcode can view this album
              <% end %>
            </p>
          </div>
        </label>
      <% end %>
    </div>
  </div>

  <div class="form-group passcode-group" style="display: none;">
    <%= f.label :passcode, "Album Passcode" %>
    <%= f.text_field :passcode, class: "form-control", 
                     placeholder: "Enter a passcode (4-20 characters)" %>
    <small class="form-text">
      This passcode will allow anyone to access the album for 30 days.
    </small>
  </div>

  <div class="form-actions">
    <%= f.submit "Create Album", class: "btn btn-primary" %>
    <%= link_to "Cancel", family_albums_path(@family), class: "btn btn-secondary" %>
  </div>
<% end %>

<script>
document.addEventListener('DOMContentLoaded', function() {
  const privacyRadios = document.querySelectorAll('.privacy-radio');
  const passcodeGroup = document.querySelector('.passcode-group');

  privacyRadios.forEach(radio => {
    radio.addEventListener('change', function() {
      if (this.value === 'passcode_protected') {
        passcodeGroup.style.display = 'block';
      } else {
        passcodeGroup.style.display = 'none';
      }
    });
  });
});
</script>
```

Create `app/views/albums/edit.html.erb`:

```erb
<h1>Edit Album</h1>

<%= form_with model: [@album.family, @album], local: true, class: "album-form" do |f| %>
  <%= render 'form_errors', album: @album %>

  <div class="form-group">
    <%= f.label :title %>
    <%= f.text_field :title, class: "form-control" %>
  </div>

  <div class="form-group">
    <%= f.label :description, "Description (optional)" %>
    <%= f.text_area :description, class: "form-control", rows: 3 %>
  </div>

  <div class="form-group">
    <%= f.label :privacy_level, "Who can see this album?" %>
    <div class="privacy-options">
      <% Album::PRIVACY_LEVELS.each do |level| %>
        <label class="privacy-option">
          <%= f.radio_button :privacy_level, level, class: "privacy-radio" %>
          <div class="privacy-content">
            <strong>
              <% case level %>
              <% when 'family' %>
                <i class="icon">👥</i> Family Members
              <% when 'private' %>
                <i class="icon">🔒</i> Private (Only me)
              <% when 'passcode_protected' %>
                <i class="icon">🔐</i> Passcode Protected
              <% end %>
            </strong>
          </div>
        </label>
      <% end %>
    </div>
  </div>

  <div class="form-group passcode-group" 
       style="<%= @album.passcode_protected? ? 'display: block;' : 'display: none;' %>">
    <%= f.label :passcode, "Album Passcode" %>
    <%= f.text_field :passcode, class: "form-control" %>
    <small class="form-text">
      Leave blank to keep current passcode, or enter new one to change it.
    </small>
  </div>

  <div class="form-actions">
    <%= f.submit "Update Album", class: "btn btn-primary" %>
    <%= link_to "Cancel", [@album.family, @album], class: "btn btn-secondary" %>
  </div>
<% end %>

<script>
document.addEventListener('DOMContentLoaded', function() {
  const privacyRadios = document.querySelectorAll('.privacy-radio');
  const passcodeGroup = document.querySelector('.passcode-group');

  privacyRadios.forEach(radio => {
    radio.addEventListener('change', function() {
      if (this.value === 'passcode_protected') {
        passcodeGroup.style.display = 'block';
      } else {
        passcodeGroup.style.display = 'none';
      }
    });
  });
});
</script>
```

Create `app/views/albums/passcode_required.html.erb`:

```erb
<div class="passcode-container">
  <div class="passcode-form-wrapper">
    <div class="passcode-header">
      <h1><%= @album.title %></h1>
      <p>This album is protected with a passcode</p>
      <i class="lock-icon">🔐</i>
    </div>

    <%= form_with url: access_with_passcode_family_album_path(@album.family, @album), 
                  method: :post, local: true, class: "passcode-form" do |f| %>
      <div class="form-group">
        <%= f.label :passcode, "Enter Passcode" %>
        <%= f.text_field :passcode, class: "form-control passcode-input", 
                         placeholder: "Enter the album passcode", 
                         autofocus: true, autocomplete: "off" %>
      </div>

      <div class="form-actions">
        <%= f.submit "Access Album", class: "btn btn-primary btn-lg" %>
      </div>
    <% end %>

    <div class="passcode-help">
      <p>Ask the album creator for the passcode to access these photos.</p>
      <%= link_to "← Back to Family", @album.family, class: "btn btn-secondary" %>
    </div>
  </div>
</div>
```

Create `app/views/albums/_form_errors.html.erb`:

```erb
<% if album.errors.any? %>
  <div class="error-messages">
    <h4><%= pluralize(album.errors.count, "error") %> prohibited this album from being saved:</h4>
    <ul>
      <% album.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

### 2. Update Routes
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
    resources :albums do
      member do
        patch :add_photos
        delete 'remove_photo/:photo_id', to: 'albums#remove_photo', as: :remove_photo
        patch :reorder_photos
        patch 'set_cover_photo/:photo_id', to: 'albums#set_cover_photo', as: :set_cover_photo
        post :access_with_passcode
      end
    end

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

### 3. Add Album Styles
Update `app/assets/stylesheets/application.css`:

```css
/* Album Grid Styles */
.albums-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #dee2e6;
}

.albums-actions {
  display: flex;
  gap: 1rem;
  align-items: center;
}

.albums-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 2rem;
  margin-bottom: 2rem;
}

.album-card {
  background: white;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.album-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.15);
}

.album-link {
  text-decoration: none;
  color: inherit;
  display: block;
}

.album-cover {
  position: relative;
  width: 100%;
  height: 200px;
  overflow: hidden;
  background: #f8f9fa;
}

.cover-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.no-photos-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #6c757d;
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
}

.album-icon {
  font-size: 3rem;
  margin-bottom: 0.5rem;
}

.album-overlay {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: linear-gradient(transparent, rgba(0,0,0,0.7));
  padding: 1rem;
  color: white;
}

.album-stats {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.photo-count {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9rem;
}

.privacy-badge {
  padding: 0.25rem 0.5rem;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: bold;
}

.privacy-private {
  background: rgba(220, 53, 69, 0.2);
  color: #dc3545;
}

.privacy-passcode_protected {
  background: rgba(255, 193, 7, 0.2);
  color: #ffc107;
}

.album-info {
  padding: 1.5rem;
}

.album-title {
  margin: 0 0 0.5rem 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: #333;
}

.album-description {
  margin: 0 0 1rem 0;
  color: #6c757d;
  line-height: 1.4;
}

.album-meta {
  color: #8e8e93;
  font-size: 0.875rem;
}

.album-actions {
  padding: 0 1.5rem 1.5rem;
  display: flex;
  gap: 0.5rem;
}

/* Album Detail Styles */
.album-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 2rem;
  padding-bottom: 1.5rem;
  border-bottom: 2px solid #dee2e6;
}

.album-title-section h1 {
  margin: 0 0 0.5rem 0;
  color: #333;
  font-size: 2rem;
}

.album-description {
  color: #6c757d;
  margin-bottom: 1rem;
  line-height: 1.6;
}

.album-meta {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  align-items: center;
  color: #8e8e93;
  font-size: 0.9rem;
}

.album-meta .privacy-badge {
  margin-left: 0.5rem;
}

.edit-actions {
  display: flex;
  gap: 0.5rem;
}

/* Photo Management Panel */
.photo-management-panel {
  background: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 8px;
  margin-bottom: 2rem;
  padding: 1.5rem;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.panel-header h3 {
  margin: 0;
  color: #333;
}

.available-photos-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.available-photo {
  position: relative;
}

.photo-checkbox-label {
  display: block;
  cursor: pointer;
  position: relative;
}

.photo-checkbox {
  position: absolute;
  top: 8px;
  right: 8px;
  z-index: 2;
  width: 20px;
  height: 20px;
}

.selectable-photo {
  width: 100%;
  height: 100px;
  object-fit: cover;
  border-radius: 6px;
  border: 2px solid transparent;
  transition: border-color 0.2s;
}

.photo-checkbox:checked + .selectable-photo {
  border-color: #007bff;
}

.photo-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 123, 255, 0.8);
  display: none;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 1.5rem;
  border-radius: 6px;
}

.photo-checkbox:checked ~ .photo-overlay {
  display: flex;
}

.photo-title {
  margin-top: 0.5rem;
  font-size: 0.8rem;
  text-align: center;
  color: #6c757d;
}

.panel-actions {
  text-align: center;
}

/* Album Photos Grid */
.album-photos-container {
  margin-top: 2rem;
}

.album-photos-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 1.5rem;
}

.album-photo-item {
  position: relative;
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  transition: transform 0.2s;
}

.album-photo-item:hover {
  transform: translateY(-2px);
}

.album-photo-item.dragging {
  opacity: 0.5;
  transform: rotate(5deg);
}

.photo-link {
  display: block;
}

.album-photo-image {
  width: 100%;
  height: 200px;
  object-fit: cover;
}

.photo-controls {
  position: absolute;
  top: 8px;
  right: 8px;
  display: flex;
  gap: 0.5rem;
  opacity: 0;
  transition: opacity 0.2s;
}

.album-photo-item:hover .photo-controls {
  opacity: 1;
}

.set-cover-btn,
.remove-photo-btn {
  width: 32px;
  height: 32px;
  border: none;
  border-radius: 50%;
  background: rgba(0,0,0,0.7);
  color: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background-color 0.2s;
}

.set-cover-btn:hover {
  background: rgba(255, 193, 7, 0.9);
}

.set-cover-btn.active {
  background: #ffc107;
  color: #000;
}

.remove-photo-btn:hover {
  background: rgba(220, 53, 69, 0.9);
}

.drag-handle {
  position: absolute;
  top: 8px;
  left: 8px;
  width: 32px;
  height: 32px;
  background: rgba(0,0,0,0.7);
  color: white;
  border-radius: 50%;
  display: none;
  align-items: center;
  justify-content: center;
  cursor: move;
}

.reorder-mode .drag-handle {
  display: flex;
}

.photo-info {
  padding: 1rem;
}

.photo-title {
  margin: 0 0 0.5rem 0;
  font-size: 1rem;
  font-weight: 600;
  color: #333;
}

.photo-caption {
  margin: 0 0 0.5rem 0;
  color: #6c757d;
  font-size: 0.875rem;
  font-style: italic;
}

.added-by {
  color: #8e8e93;
  font-size: 0.8rem;
}

/* Empty Album State */
.empty-album {
  text-align: center;
  padding: 4rem 2rem;
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.empty-album-content {
  max-width: 400px;
  margin: 0 auto;
}

.empty-icon {
  font-size: 4rem;
  margin-bottom: 1rem;
  display: block;
}

.empty-album h3 {
  color: #6c757d;
  margin-bottom: 1rem;
}

/* Privacy Options */
.privacy-options {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-top: 0.5rem;
}

.privacy-option {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
  padding: 1rem;
  border: 2px solid #e9ecef;
  border-radius: 8px;
  cursor: pointer;
  transition: border-color 0.2s, background-color 0.2s;
}

.privacy-option:hover {
  border-color: #007bff;
  background-color: #f8f9ff;
}

.privacy-radio:checked + .privacy-content {
  color: #007bff;
}

.privacy-option:has(.privacy-radio:checked) {
  border-color: #007bff;
  background-color: #f8f9ff;
}

.privacy-content {
  flex: 1;
}

.privacy-content strong {
  display: block;
  margin-bottom: 0.25rem;
}

.privacy-content p {
  margin: 0;
  color: #6c757d;
  font-size: 0.9rem;
}

/* Passcode Form */
.passcode-container {
  min-height: 60vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.passcode-form-wrapper {
  background: white;
  padding: 3rem;
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.1);
  text-align: center;
  max-width: 400px;
  width: 100%;
}

.passcode-header h1 {
  margin: 0 0 0.5rem 0;
  color: #333;
}

.lock-icon {
  font-size: 3rem;
  margin: 1.5rem 0;
  display: block;
}

.passcode-input {
  text-align: center;
  font-size: 1.2rem;
  letter-spacing: 0.1em;
  margin-bottom: 1.5rem;
}

.passcode-help {
  margin-top: 2rem;
  padding-top: 1.5rem;
  border-top: 1px solid #dee2e6;
}

.passcode-help p {
  color: #6c757d;
  margin-bottom: 1rem;
}

/* Responsive Design */
@media (max-width: 768px) {
  .albums-header {
    flex-direction: column;
    align-items: stretch;
    gap: 1rem;
  }

  .albums-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  .album-header {
    flex-direction: column;
    gap: 1rem;
  }

  .album-photos-grid {
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
  }

  .available-photos-grid {
    grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
  }

  .privacy-options {
    gap: 0.5rem;
  }

  .privacy-option {
    padding: 0.75rem;
  }
}
```

### 4. Add JavaScript for Photo Management
Create `app/assets/javascripts/album_management.js`:

```javascript
document.addEventListener('DOMContentLoaded', function() {
  initializeAlbumManagement();
  initializePhotoSelection();
  initializePhotoReordering();
  initializePhotoControls();
});

function initializeAlbumManagement() {
  const manageBtnEl = document.getElementById('manage-photos-btn');
  const reorderBtnEl = document.getElementById('reorder-photos-btn');
  const closeBtnEl = document.getElementById('close-management-btn');
  const addFirstBtnEl = document.getElementById('add-first-photo-btn');
  const panelEl = document.getElementById('photo-management-panel');
  const gridEl = document.getElementById('album-photos-grid');

  if (manageBtnEl) {
    manageBtnEl.addEventListener('click', function() {
      showPhotoManagementPanel();
    });
  }

  if (reorderBtnEl) {
    reorderBtnEl.addEventListener('click', function() {
      toggleReorderMode();
    });
  }

  if (closeBtnEl) {
    closeBtnEl.addEventListener('click', function() {
      hidePhotoManagementPanel();
    });
  }

  if (addFirstBtnEl) {
    addFirstBtnEl.addEventListener('click', function() {
      showPhotoManagementPanel();
    });
  }

  function showPhotoManagementPanel() {
    if (panelEl) {
      panelEl.style.display = 'block';
      manageBtnEl.style.display = 'none';
      reorderBtnEl.style.display = 'inline-block';
    }
  }

  function hidePhotoManagementPanel() {
    if (panelEl) {
      panelEl.style.display = 'none';
      manageBtnEl.style.display = 'inline-block';
      reorderBtnEl.style.display = 'none';
    }
    exitReorderMode();
  }

  function toggleReorderMode() {
    if (gridEl) {
      const isReorderMode = gridEl.classList.contains('reorder-mode');
      if (isReorderMode) {
        exitReorderMode();
      } else {
        enterReorderMode();
      }
    }
  }

  function enterReorderMode() {
    gridEl.classList.add('reorder-mode');
    reorderBtnEl.textContent = 'Exit Reorder';
    reorderBtnEl.classList.add('btn-warning');
    reorderBtnEl.classList.remove('btn-outline');
  }

  function exitReorderMode() {
    if (gridEl) {
      gridEl.classList.remove('reorder-mode');
      reorderBtnEl.textContent = 'Reorder Photos';
      reorderBtnEl.classList.remove('btn-warning');
      reorderBtnEl.classList.add('btn-outline');
    }
  }
}

function initializePhotoSelection() {
  const checkboxes = document.querySelectorAll('.photo-checkbox');
  const submitBtn = document.getElementById('add-photos-submit');

  if (!submitBtn) return;

  checkboxes.forEach(checkbox => {
    checkbox.addEventListener('change', updateSubmitButton);
  });

  function updateSubmitButton() {
    const checkedBoxes = document.querySelectorAll('.photo-checkbox:checked');
    submitBtn.disabled = checkedBoxes.length === 0;
    
    if (checkedBoxes.length > 0) {
      submitBtn.textContent = `Add ${checkedBoxes.length} Selected Photo${checkedBoxes.length > 1 ? 's' : ''}`;
    } else {
      submitBtn.textContent = 'Add Selected Photos';
    }
  }
}

function initializePhotoReordering() {
  const gridEl = document.getElementById('album-photos-grid');
  if (!gridEl || gridEl.dataset.canEdit !== 'true') return;

  let draggedElement = null;

  gridEl.addEventListener('dragstart', function(e) {
    if (!gridEl.classList.contains('reorder-mode')) return;
    
    draggedElement = e.target.closest('.album-photo-item');
    if (draggedElement) {
      draggedElement.classList.add('dragging');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/html', draggedElement.outerHTML);
    }
  });

  gridEl.addEventListener('dragover', function(e) {
    if (!gridEl.classList.contains('reorder-mode') || !draggedElement) return;
    
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';

    const afterElement = getDragAfterElement(gridEl, e.clientY);
    if (afterElement == null) {
      gridEl.appendChild(draggedElement);
    } else {
      gridEl.insertBefore(draggedElement, afterElement);
    }
  });

  gridEl.addEventListener('dragend', function(e) {
    if (draggedElement) {
      draggedElement.classList.remove('dragging');
      savePhotoOrder();
      draggedElement = null;
    }
  });

  // Make photo items draggable in reorder mode
  const photoItems = gridEl.querySelectorAll('.album-photo-item');
  photoItems.forEach(item => {
    item.draggable = true;
  });

  function getDragAfterElement(container, y) {
    const draggableElements = [...container.querySelectorAll('.album-photo-item:not(.dragging)')];
    
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect();
      const offset = y - box.top - box.height / 2;
      
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child };
      } else {
        return closest;
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element;
  }

  function savePhotoOrder() {
    const photoIds = Array.from(gridEl.querySelectorAll('.album-photo-item'))
                          .map(item => item.dataset.photoId);
    
    const albumId = gridEl.dataset.albumId;
    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

    fetch(`/families/${getAlbumFamilyId()}/albums/${albumId}/reorder_photos`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token,
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify({ photo_ids: photoIds })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('Photo order updated successfully');
      }
    })
    .catch(error => {
      console.error('Error updating photo order:', error);
    });
  }

  function getAlbumFamilyId() {
    // Extract family ID from current URL
    const pathParts = window.location.pathname.split('/');
    const familiesIndex = pathParts.indexOf('families');
    return familiesIndex !== -1 ? pathParts[familiesIndex + 1] : null;
  }
}

function initializePhotoControls() {
  const gridEl = document.getElementById('album-photos-grid');
  if (!gridEl || gridEl.dataset.canEdit !== 'true') return;

  gridEl.addEventListener('click', function(e) {
    const setCoverBtn = e.target.closest('.set-cover-btn');
    const removeBtn = e.target.closest('.remove-photo-btn');

    if (setCoverBtn) {
      e.preventDefault();
      e.stopPropagation();
      setCoverPhoto(setCoverBtn.dataset.photoId);
    }

    if (removeBtn) {
      e.preventDefault();
      e.stopPropagation();
      removePhotoFromAlbum(removeBtn.dataset.photoId);
    }
  });

  function setCoverPhoto(photoId) {
    const albumId = gridEl.dataset.albumId;
    const familyId = getAlbumFamilyId();
    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

    fetch(`/families/${familyId}/albums/${albumId}/set_cover_photo/${photoId}`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': token,
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => {
      if (response.ok) {
        // Update UI to show new cover photo
        document.querySelectorAll('.set-cover-btn').forEach(btn => {
          btn.classList.remove('active');
        });
        document.querySelector(`[data-photo-id="${photoId}"] .set-cover-btn`).classList.add('active');
        
        showNotification('Cover photo updated successfully');
      }
    })
    .catch(error => {
      console.error('Error setting cover photo:', error);
      showNotification('Failed to update cover photo', 'error');
    });
  }

  function removePhotoFromAlbum(photoId) {
    if (!confirm('Remove this photo from the album?')) return;

    const albumId = gridEl.dataset.albumId;
    const familyId = getAlbumFamilyId();
    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

    fetch(`/families/${familyId}/albums/${albumId}/remove_photo/${photoId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': token,
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => {
      if (response.ok) {
        // Remove photo item from DOM
        const photoItem = document.querySelector(`[data-photo-id="${photoId}"]`);
        if (photoItem) {
          photoItem.remove();
        }
        showNotification('Photo removed from album');
      }
    })
    .catch(error => {
      console.error('Error removing photo:', error);
      showNotification('Failed to remove photo', 'error');
    });
  }

  function getAlbumFamilyId() {
    const pathParts = window.location.pathname.split('/');
    const familiesIndex = pathParts.indexOf('families');
    return familiesIndex !== -1 ? pathParts[familiesIndex + 1] : null;
  }

  function showNotification(message, type = 'success') {
    // Simple notification system
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 1rem 1.5rem;
      background: ${type === 'error' ? '#dc3545' : '#28a745'};
      color: white;
      border-radius: 4px;
      z-index: 1000;
      animation: slideIn 0.3s ease;
    `;

    document.body.appendChild(notification);

    setTimeout(() => {
      notification.style.animation = 'slideOut 0.3s ease forwards';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
  @keyframes slideIn {
    from { transform: translateX(100%); opacity: 0; }
    to { transform: translateX(0); opacity: 1; }
  }
  
  @keyframes slideOut {
    from { transform: translateX(0); opacity: 1; }
    to { transform: translateX(100%); opacity: 0; }
  }
`;
document.head.appendChild(style);
```

Include the JavaScript in your layout by adding to `app/views/layouts/application.html.erb`:

```erb
<%= javascript_include_tag "album_management" %>
```

## Testing Requirements

### 1. Create Controller Tests
Create `spec/controllers/albums_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe AlbumsController, type: :controller do
  let(:family) { create(:family) }
  let(:user) { family.created_by }
  let(:album) { create(:album, family: family, created_by: user) }

  before { sign_in user }

  describe 'GET #index' do
    it 'displays family albums' do
      get :index, params: { family_id: family.id }
      expect(response).to be_successful
      expect(assigns(:albums)).to include(album)
    end
  end

  describe 'GET #show' do
    it 'displays the album' do
      get :show, params: { family_id: family.id, id: album.id }
      expect(response).to be_successful
      expect(assigns(:album)).to eq(album)
    end

    context 'passcode protected album' do
      let(:protected_album) { create(:album, :passcode_protected, family: family) }

      it 'renders passcode form for non-owner' do
        other_user = create(:user)
        family.add_member(other_user, role: 'viewer')
        sign_in other_user

        get :show, params: { family_id: family.id, id: protected_album.id }
        expect(response).to render_template(:passcode_required)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        family_id: family.id,
        album: {
          title: 'Test Album',
          description: 'A test album',
          privacy_level: 'family'
        }
      }
    end

    it 'creates a new album' do
      expect {
        post :create, params: valid_params
      }.to change(Album, :count).by(1)
    end

    it 'redirects to the album' do
      post :create, params: valid_params
      expect(response).to redirect_to([family, Album.last])
    end
  end

  describe 'PATCH #add_photos' do
    let(:photos) { create_list(:photo, 2, user: user) }

    it 'adds photos to album' do
      expect {
        patch :add_photos, params: { 
          family_id: family.id, 
          id: album.id, 
          photo_ids: photos.map(&:id) 
        }
      }.to change(album.photos, :count).by(2)
    end
  end

  describe 'DELETE #remove_photo' do
    let(:photo) { create(:photo, user: user) }

    before { album.add_photo(photo, user) }

    it 'removes photo from album' do
      expect {
        delete :remove_photo, params: { 
          family_id: family.id, 
          id: album.id, 
          photo_id: photo.id 
        }
      }.to change(album.photos, :count).by(-1)
    end
  end
end
```

### 2. Create Feature Tests
Create `spec/features/album_management_spec.rb`:

```ruby
require 'rails_helper'

RSpec.feature 'Album Management', type: :feature do
  let(:family) { create(:family) }
  let(:user) { family.created_by }
  
  before { sign_in user }

  scenario 'User creates a new album' do
    visit family_albums_path(family)
    click_link 'Create Album'

    fill_in 'Title', with: 'My New Album'
    fill_in 'Description', with: 'A collection of family photos'
    choose 'Family Members'

    click_button 'Create Album'

    expect(page).to have_content('Album created successfully')
    expect(page).to have_content('My New Album')
  end

  scenario 'User creates passcode-protected album' do
    visit new_family_album_path(family)

    fill_in 'Title', with: 'Secret Album'
    choose 'Passcode Protected'
    fill_in 'Album Passcode', with: 'SECRET123'

    click_button 'Create Album'

    expect(page).to have_content('Album created successfully')
    expect(page).to have_content('Passcode Protected')
  end

  scenario 'User adds photos to album' do
    album = create(:album, family: family, created_by: user)
    photos = create_list(:photo, 2, user: user)

    visit family_album_path(family, album)
    click_button 'Manage Photos'

    photos.each do |photo|
      check "photo_ids_#{photo.id}"
    end

    click_button 'Add Selected Photos'

    expect(page).to have_content('2 photos added to album')
    expect(album.reload.photo_count).to eq(2)
  end

  scenario 'User sets cover photo' do
    album = create(:album, :with_photos, family: family, created_by: user)
    
    visit family_album_path(family, album)
    
    # This would require JavaScript testing with Capybara-webkit or similar
    # For now, we'll test the controller action
  end
end
```

## Files to Create/Modify

- `app/views/albums/` - Album views directory with all templates
- `app/assets/stylesheets/application.css` - Album-specific styles
- `app/assets/javascripts/album_management.js` - Photo management JavaScript
- `config/routes.rb` - Album-related routes
- `spec/controllers/albums_controller_spec.rb` - Controller tests
- `spec/features/album_management_spec.rb` - Feature tests

## Deliverables

1. Complete album interface with photo management
2. Drag-and-drop photo organization
3. Cover photo selection
4. Privacy controls and passcode protection
5. Responsive design for all screen sizes
6. JavaScript-enhanced user interactions
7. Comprehensive test coverage

## Notes for Junior Developer

- The interface uses progressive enhancement - core functionality works without JavaScript
- Drag-and-drop uses the HTML5 Drag and Drop API
- AJAX requests handle photo reordering and management without page reloads
- CSS Grid provides responsive layout for photo galleries
- Privacy badges indicate album access levels
- The passcode system allows temporary sharing outside the family

## Validation Steps

1. Create albums with different privacy levels
2. Test photo addition and removal
3. Verify drag-and-drop reordering works
4. Test cover photo selection
5. Try accessing passcode-protected albums
6. Check responsive behavior on mobile
7. Run test suite: `bundle exec rspec spec/controllers/albums_controller_spec.rb`

## Next Steps

After completing this ticket, you'll move to Phase 6: Polish & Testing for final cleanup, performance optimization, and production preparation.