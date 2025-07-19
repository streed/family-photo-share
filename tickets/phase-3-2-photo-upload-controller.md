# Phase 3, Ticket 2: Photo Upload Controller and Views

**Priority**: High  
**Estimated Time**: 3-4 hours  
**Prerequisites**: Completed Phase 3, Ticket 1  

## Objective

Create the photos controller with upload functionality, photo viewing, and management interfaces. Implement drag-and-drop upload with preview capabilities.

## Acceptance Criteria

- [ ] Photos controller with CRUD operations
- [ ] Photo upload form with drag-and-drop support
- [ ] Photo gallery view for users
- [ ] Individual photo detail view
- [ ] Photo editing and deletion functionality
- [ ] Responsive photo grid layout
- [ ] JavaScript-enhanced upload experience
- [ ] Progress indicators for uploads

## Technical Requirements

### 1. Create Photos Controller
Create `app/controllers/photos_controller.rb`:

```ruby
class PhotosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_photo, only: [:show, :edit, :update, :destroy]
  before_action :check_photo_owner, only: [:edit, :update, :destroy]

  def index
    @photos = current_user.photos.recent
                         .includes(image_attachment: :blob)
                         .page(params[:page])
                         .per(20)
  end

  def show
    # Photo detail view - will be accessible to family members later
  end

  def new
    @photo = current_user.photos.build
  end

  def create
    @photo = current_user.photos.build(photo_params)

    if @photo.save
      redirect_to @photo, notice: 'Photo uploaded successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Edit photo metadata
  end

  def update
    if @photo.update(photo_params.except(:image))
      redirect_to @photo, notice: 'Photo updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @photo.destroy
    redirect_to photos_path, notice: 'Photo deleted successfully!'
  end

  # Bulk upload endpoint for AJAX requests
  def bulk_create
    @results = []
    
    params[:photos]&.each do |photo_params|
      photo = current_user.photos.build(photo_params.permit(:image, :title))
      photo.title = photo.image.filename.to_s if photo.title.blank? && photo.image.attached?
      
      if photo.save
        @results << { success: true, photo_id: photo.id, title: photo.title }
      else
        @results << { success: false, errors: photo.errors.full_messages }
      end
    end

    render json: @results
  end

  private

  def set_photo
    @photo = Photo.find(params[:id])
  end

  def check_photo_owner
    redirect_to photos_path, alert: 'Not authorized to modify this photo.' unless @photo.user == current_user
  end

  def photo_params
    params.require(:photo).permit(:image, :title, :description, :location, :taken_at)
  end
end
```

### 2. Create Photo Views

Create `app/views/photos/index.html.erb`:

```erb
<div class="photos-header">
  <h1>My Photos</h1>
  <div class="photos-actions">
    <%= link_to "Upload Photos", new_photo_path, class: "btn btn-primary" %>
    <span class="photo-count"><%= current_user.photo_count %> photos</span>
  </div>
</div>

<% if @photos.any? %>
  <div class="photos-grid">
    <% @photos.each do |photo| %>
      <div class="photo-card">
        <%= link_to photo_path(photo), class: "photo-link" do %>
          <div class="photo-thumbnail">
            <%= photo_tag(photo, :thumbnail, loading: "lazy") %>
          </div>
          <div class="photo-info">
            <h3 class="photo-title"><%= truncate(photo.title, length: 30) %></h3>
            <p class="photo-date"><%= formatted_photo_date(photo) %></p>
          </div>
        <% end %>
        
        <div class="photo-actions">
          <%= link_to "Edit", edit_photo_path(photo), class: "btn btn-sm btn-secondary" %>
          <%= link_to "Delete", photo_path(photo), method: :delete, 
                      class: "btn btn-sm btn-danger",
                      confirm: "Are you sure you want to delete this photo?" %>
        </div>
      </div>
    <% end %>
  </div>

  <%= paginate @photos if respond_to?(:paginate) %>
<% else %>
  <div class="empty-state">
    <h2>No photos yet</h2>
    <p>Start building your photo collection!</p>
    <%= link_to "Upload Your First Photo", new_photo_path, class: "btn btn-primary btn-lg" %>
  </div>
<% end %>
```

Create `app/views/photos/show.html.erb`:

```erb
<div class="photo-detail">
  <div class="photo-header">
    <div class="photo-navigation">
      <%= link_to "← Back to Photos", photos_path, class: "btn btn-secondary" %>
      
      <% if @photo.user == current_user %>
        <div class="photo-owner-actions">
          <%= link_to "Edit", edit_photo_path(@photo), class: "btn btn-primary" %>
          <%= link_to "Delete", photo_path(@photo), method: :delete, 
                      class: "btn btn-danger",
                      confirm: "Are you sure you want to delete this photo?" %>
        </div>
      <% end %>
    </div>
  </div>

  <div class="photo-content">
    <div class="photo-display">
      <%= photo_tag(@photo, :large, class: "main-photo") %>
    </div>

    <div class="photo-metadata">
      <h1><%= @photo.title %></h1>
      
      <% if @photo.description.present? %>
        <div class="photo-description">
          <%= simple_format(@photo.description) %>
        </div>
      <% end %>

      <div class="photo-details">
        <div class="detail-row">
          <strong>Uploaded by:</strong>
          <%= link_to @photo.user.display_name_or_full_name, profile_path(@photo.user) %>
        </div>

        <div class="detail-row">
          <strong>Date taken:</strong>
          <%= @photo.taken_at ? formatted_photo_date(@photo) : "Unknown" %>
        </div>

        <% if @photo.location.present? %>
          <div class="detail-row">
            <strong>Location:</strong>
            <%= @photo.location %>
          </div>
        <% end %>

        <div class="detail-row">
          <strong>File size:</strong>
          <%= @photo.formatted_file_size %>
        </div>

        <% if @photo.image_dimensions %>
          <div class="detail-row">
            <strong>Dimensions:</strong>
            <%= @photo.image_dimensions %>
          </div>
        <% end %>

        <div class="detail-row">
          <strong>Uploaded:</strong>
          <%= @photo.created_at.strftime("%B %d, %Y at %I:%M %p") %>
        </div>
      </div>
    </div>
  </div>
</div>
```

Create `app/views/photos/new.html.erb`:

```erb
<h1>Upload Photos</h1>

<div class="upload-container">
  <!-- Standard form upload -->
  <div class="standard-upload">
    <%= form_with model: @photo, local: true, multipart: true, class: "photo-form" do |f| %>
      <%= render 'form_errors', photo: @photo %>

      <div class="form-group">
        <%= f.label :image, "Select Photo" %>
        <%= f.file_field :image, accept: "image/*", class: "form-control", id: "photo-file-input" %>
        <small class="form-text">Supported formats: JPEG, PNG, GIF. Maximum size: 10MB</small>
      </div>

      <div class="form-group">
        <%= f.label :title %>
        <%= f.text_field :title, class: "form-control", placeholder: "Enter a title for your photo" %>
      </div>

      <div class="form-group">
        <%= f.label :description, "Description (optional)" %>
        <%= f.text_area :description, class: "form-control", rows: 3, placeholder: "Add a description..." %>
      </div>

      <div class="form-group">
        <%= f.label :location, "Location (optional)" %>
        <%= f.text_field :location, class: "form-control", placeholder: "Where was this photo taken?" %>
      </div>

      <div class="form-group">
        <%= f.label :taken_at, "Date taken (optional)" %>
        <%= f.datetime_local_field :taken_at, class: "form-control" %>
      </div>

      <div class="form-actions">
        <%= f.submit "Upload Photo", class: "btn btn-primary", id: "upload-btn" %>
        <%= link_to "Cancel", photos_path, class: "btn btn-secondary" %>
      </div>
    <% end %>
  </div>

  <!-- Drag and drop upload -->
  <div class="drag-drop-upload" id="drag-drop-area">
    <div class="drop-zone" id="drop-zone">
      <div class="drop-zone-content">
        <i class="upload-icon">📷</i>
        <h3>Drag & Drop Photos Here</h3>
        <p>or <a href="#" id="browse-files">browse files</a></p>
        <small>Supports multiple files</small>
      </div>
      
      <div class="upload-progress" id="upload-progress" style="display: none;">
        <div class="progress-bar">
          <div class="progress-fill" id="progress-fill"></div>
        </div>
        <p class="progress-text" id="progress-text">Uploading...</p>
      </div>
    </div>

    <div class="upload-results" id="upload-results"></div>
  </div>
</div>

<!-- Hidden file input for drag-drop -->
<input type="file" id="hidden-file-input" multiple accept="image/*" style="display: none;">
```

Create `app/views/photos/edit.html.erb`:

```erb
<h1>Edit Photo</h1>

<div class="edit-photo-container">
  <div class="current-photo">
    <%= photo_tag(@photo, :medium) %>
  </div>

  <div class="edit-form">
    <%= form_with model: @photo, local: true, class: "photo-form" do |f| %>
      <%= render 'form_errors', photo: @photo %>

      <div class="form-group">
        <%= f.label :title %>
        <%= f.text_field :title, class: "form-control" %>
      </div>

      <div class="form-group">
        <%= f.label :description, "Description (optional)" %>
        <%= f.text_area :description, class: "form-control", rows: 4 %>
      </div>

      <div class="form-group">
        <%= f.label :location, "Location (optional)" %>
        <%= f.text_field :location, class: "form-control" %>
      </div>

      <div class="form-group">
        <%= f.label :taken_at, "Date taken (optional)" %>
        <%= f.datetime_local_field :taken_at, class: "form-control", 
            value: @photo.taken_at&.strftime("%Y-%m-%dT%H:%M") %>
      </div>

      <div class="form-actions">
        <%= f.submit "Update Photo", class: "btn btn-primary" %>
        <%= link_to "Cancel", @photo, class: "btn btn-secondary" %>
      </div>
    <% end %>
  </div>
</div>
```

Create `app/views/photos/_form_errors.html.erb`:

```erb
<% if photo.errors.any? %>
  <div class="error-messages">
    <h4><%= pluralize(photo.errors.count, "error") %> prohibited this photo from being saved:</h4>
    <ul>
      <% photo.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

### 3. Add Photos to Routes
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

  root 'photos#index'

  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end
```

### 4. Add Photo Styles to CSS
Update `app/assets/stylesheets/application.css`:

```css
/* Photo Grid Styles */
.photos-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #dee2e6;
}

.photos-actions {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.photo-count {
  color: #6c757d;
  font-size: 0.9rem;
}

.photos-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.photo-card {
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.photo-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}

.photo-link {
  text-decoration: none;
  color: inherit;
  display: block;
}

.photo-thumbnail {
  width: 100%;
  height: 200px;
  overflow: hidden;
  background: #f8f9fa;
  display: flex;
  align-items: center;
  justify-content: center;
}

.photo-thumbnail img {
  width: 100%;
  height: 100%;
  object-fit: cover;
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

.photo-date {
  margin: 0;
  font-size: 0.875rem;
  color: #6c757d;
}

.photo-actions {
  padding: 0 1rem 1rem;
  display: flex;
  gap: 0.5rem;
}

/* Photo Detail Styles */
.photo-detail {
  max-width: 1200px;
  margin: 0 auto;
}

.photo-header {
  margin-bottom: 2rem;
}

.photo-navigation {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.photo-owner-actions {
  display: flex;
  gap: 0.5rem;
}

.photo-content {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 2rem;
  align-items: start;
}

.photo-display {
  background: white;
  border-radius: 8px;
  padding: 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.main-photo {
  width: 100%;
  height: auto;
  max-height: 70vh;
  object-fit: contain;
  border-radius: 4px;
}

.photo-metadata {
  background: white;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.photo-metadata h1 {
  margin: 0 0 1rem 0;
  font-size: 1.5rem;
  color: #333;
}

.photo-description {
  margin-bottom: 1.5rem;
  color: #555;
}

.detail-row {
  margin-bottom: 0.75rem;
  font-size: 0.9rem;
}

.detail-row strong {
  color: #333;
  display: inline-block;
  min-width: 100px;
}

/* Upload Styles */
.upload-container {
  max-width: 800px;
  margin: 0 auto;
}

.standard-upload {
  background: white;
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  margin-bottom: 2rem;
}

.drag-drop-upload {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  padding: 2rem;
}

.drop-zone {
  border: 2px dashed #dee2e6;
  border-radius: 8px;
  padding: 3rem 2rem;
  text-align: center;
  transition: border-color 0.3s;
}

.drop-zone.drag-over {
  border-color: #007bff;
  background-color: #f8f9ff;
}

.drop-zone-content h3 {
  margin: 1rem 0 0.5rem 0;
  color: #333;
}

.upload-icon {
  font-size: 3rem;
  margin-bottom: 1rem;
  display: block;
}

.upload-progress {
  margin-top: 2rem;
}

.progress-bar {
  width: 100%;
  height: 20px;
  background-color: #e9ecef;
  border-radius: 10px;
  overflow: hidden;
  margin-bottom: 1rem;
}

.progress-fill {
  height: 100%;
  background-color: #007bff;
  transition: width 0.3s;
  border-radius: 10px;
}

.upload-results {
  margin-top: 2rem;
}

.upload-result {
  padding: 1rem;
  margin-bottom: 0.5rem;
  border-radius: 4px;
}

.upload-success {
  background-color: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.upload-error {
  background-color: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

/* Empty State */
.empty-state {
  text-align: center;
  padding: 4rem 2rem;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.empty-state h2 {
  color: #6c757d;
  margin-bottom: 1rem;
}

/* Responsive Design */
@media (max-width: 768px) {
  .photos-header {
    flex-direction: column;
    align-items: stretch;
    gap: 1rem;
  }

  .photos-grid {
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
  }

  .photo-content {
    grid-template-columns: 1fr;
  }

  .photo-navigation {
    flex-direction: column;
    gap: 1rem;
  }
}
```

### 5. Add JavaScript for Drag-and-Drop
Create `app/assets/javascripts/photo_upload.js`:

```javascript
document.addEventListener('DOMContentLoaded', function() {
  const dropZone = document.getElementById('drop-zone');
  const hiddenFileInput = document.getElementById('hidden-file-input');
  const browseLink = document.getElementById('browse-files');
  const uploadProgress = document.getElementById('upload-progress');
  const uploadResults = document.getElementById('upload-results');

  if (!dropZone) return;

  // Prevent default drag behaviors
  ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
    dropZone.addEventListener(eventName, preventDefaults, false);
    document.body.addEventListener(eventName, preventDefaults, false);
  });

  // Highlight drop zone when item is dragged over it
  ['dragenter', 'dragover'].forEach(eventName => {
    dropZone.addEventListener(eventName, highlight, false);
  });

  ['dragleave', 'drop'].forEach(eventName => {
    dropZone.addEventListener(eventName, unhighlight, false);
  });

  // Handle dropped files
  dropZone.addEventListener('drop', handleDrop, false);

  // Handle browse files link
  if (browseLink) {
    browseLink.addEventListener('click', function(e) {
      e.preventDefault();
      hiddenFileInput.click();
    });
  }

  // Handle file selection
  if (hiddenFileInput) {
    hiddenFileInput.addEventListener('change', function() {
      handleFiles(this.files);
    });
  }

  function preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
  }

  function highlight() {
    dropZone.classList.add('drag-over');
  }

  function unhighlight() {
    dropZone.classList.remove('drag-over');
  }

  function handleDrop(e) {
    const dt = e.dataTransfer;
    const files = dt.files;
    handleFiles(files);
  }

  function handleFiles(files) {
    if (files.length === 0) return;

    const fileArray = Array.from(files);
    const imageFiles = fileArray.filter(file => file.type.startsWith('image/'));

    if (imageFiles.length === 0) {
      showError('Please select valid image files.');
      return;
    }

    uploadFiles(imageFiles);
  }

  function uploadFiles(files) {
    showProgress();
    
    const formData = new FormData();
    files.forEach((file, index) => {
      formData.append(`photos[${index}][image]`, file);
      formData.append(`photos[${index}][title]`, file.name.replace(/\.[^/.]+$/, ""));
    });

    // Get CSRF token
    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

    fetch('/photos/bulk_create', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': token,
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: formData
    })
    .then(response => response.json())
    .then(results => {
      hideProgress();
      showResults(results);
    })
    .catch(error => {
      hideProgress();
      showError('Upload failed: ' + error.message);
    });
  }

  function showProgress() {
    document.querySelector('.drop-zone-content').style.display = 'none';
    uploadProgress.style.display = 'block';
    
    // Simulate progress (real progress tracking would require more complex setup)
    let progress = 0;
    const progressInterval = setInterval(() => {
      progress += 10;
      document.getElementById('progress-fill').style.width = progress + '%';
      
      if (progress >= 90) {
        clearInterval(progressInterval);
      }
    }, 200);
  }

  function hideProgress() {
    uploadProgress.style.display = 'none';
    document.querySelector('.drop-zone-content').style.display = 'block';
    document.getElementById('progress-fill').style.width = '0%';
  }

  function showResults(results) {
    uploadResults.innerHTML = '';
    
    results.forEach(result => {
      const resultDiv = document.createElement('div');
      resultDiv.className = 'upload-result ' + (result.success ? 'upload-success' : 'upload-error');
      
      if (result.success) {
        resultDiv.innerHTML = `✅ Successfully uploaded: ${result.title}`;
      } else {
        resultDiv.innerHTML = `❌ Failed to upload: ${result.errors.join(', ')}`;
      }
      
      uploadResults.appendChild(resultDiv);
    });

    // Redirect to photos index after successful uploads
    const successCount = results.filter(r => r.success).length;
    if (successCount > 0) {
      setTimeout(() => {
        window.location.href = '/photos';
      }, 2000);
    }
  }

  function showError(message) {
    uploadResults.innerHTML = `<div class="upload-result upload-error">❌ ${message}</div>`;
  }
});
```

Include the JavaScript in your layout by adding to `app/views/layouts/application.html.erb`:

```erb
<%= javascript_include_tag "photo_upload" %>
```

## Testing Requirements

### 1. Create Controller Tests
Create `spec/controllers/photos_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe PhotosController, type: :controller do
  let(:user) { create(:user) }
  let(:photo) { create(:photo, user: user) }
  let(:other_user) { create(:user) }
  let(:other_photo) { create(:photo, user: other_user) }

  before { sign_in user }

  describe 'GET #index' do
    it 'displays user photos' do
      get :index
      expect(response).to be_successful
      expect(assigns(:photos)).to include(photo)
    end
  end

  describe 'GET #show' do
    it 'displays the photo' do
      get :show, params: { id: photo.id }
      expect(response).to be_successful
      expect(assigns(:photo)).to eq(photo)
    end
  end

  describe 'GET #new' do
    it 'displays the upload form' do
      get :new
      expect(response).to be_successful
      expect(assigns(:photo)).to be_a_new(Photo)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        photo: {
          image: fixture_file_upload('spec/fixtures/files/test_image.jpg', 'image/jpeg'),
          title: 'Test Photo',
          description: 'A test photo'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new photo' do
        expect {
          post :create, params: valid_params
        }.to change(Photo, :count).by(1)
      end

      it 'redirects to the photo' do
        post :create, params: valid_params
        expect(response).to redirect_to(Photo.last)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { { photo: { title: '' } } }

      it 'does not create a photo' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Photo, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    context 'as photo owner' do
      let(:update_params) { { id: photo.id, photo: { title: 'Updated Title' } } }

      it 'updates the photo' do
        patch :update, params: update_params
        photo.reload
        expect(photo.title).to eq('Updated Title')
      end

      it 'redirects to the photo' do
        patch :update, params: update_params
        expect(response).to redirect_to(photo)
      end
    end

    context 'as non-owner' do
      it 'redirects to photos index' do
        patch :update, params: { id: other_photo.id, photo: { title: 'Hacked' } }
        expect(response).to redirect_to(photos_path)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'as photo owner' do
      it 'deletes the photo' do
        photo # create the photo
        expect {
          delete :destroy, params: { id: photo.id }
        }.to change(Photo, :count).by(-1)
      end
    end

    context 'as non-owner' do
      it 'redirects without deleting' do
        expect {
          delete :destroy, params: { id: other_photo.id }
        }.not_to change(Photo, :count)
      end
    end
  end
end
```

### 2. Create Feature Tests
Create `spec/features/photo_management_spec.rb`:

```ruby
require 'rails_helper'

RSpec.feature 'Photo Management', type: :feature do
  let(:user) { create(:user) }
  
  before { sign_in user }

  scenario 'User uploads a photo' do
    visit new_photo_path

    attach_file 'photo[image]', Rails.root.join('spec/fixtures/files/test_image.jpg')
    fill_in 'Title', with: 'My Test Photo'
    fill_in 'Description', with: 'This is a test photo'

    click_button 'Upload Photo'

    expect(page).to have_content('Photo uploaded successfully')
    expect(page).to have_content('My Test Photo')
  end

  scenario 'User views their photo gallery' do
    photos = create_list(:photo, 3, user: user)

    visit photos_path

    expect(page).to have_content('My Photos')
    photos.each do |photo|
      expect(page).to have_content(photo.title)
    end
  end

  scenario 'User edits a photo' do
    photo = create(:photo, user: user, title: 'Original Title')

    visit edit_photo_path(photo)

    fill_in 'Title', with: 'Updated Title'
    click_button 'Update Photo'

    expect(page).to have_content('Photo updated successfully')
    expect(page).to have_content('Updated Title')
  end

  scenario 'User deletes a photo' do
    photo = create(:photo, user: user)

    visit photo_path(photo)

    click_link 'Delete'
    
    expect(page).to have_content('Photo deleted successfully')
    expect(page).not_to have_content(photo.title)
  end
end
```

## Files to Create/Modify

- `app/controllers/photos_controller.rb` - Photo CRUD operations
- `app/views/photos/index.html.erb` - Photo gallery
- `app/views/photos/show.html.erb` - Photo detail view
- `app/views/photos/new.html.erb` - Upload form
- `app/views/photos/edit.html.erb` - Edit form
- `app/views/photos/_form_errors.html.erb` - Error partial
- `config/routes.rb` - Photo routes
- `app/assets/stylesheets/application.css` - Photo styles
- `app/assets/javascripts/photo_upload.js` - Drag-drop functionality
- `spec/controllers/photos_controller_spec.rb` - Controller tests
- `spec/features/photo_management_spec.rb` - Feature tests

## Deliverables

1. Complete photo management interface
2. Drag-and-drop upload functionality
3. Responsive photo gallery
4. Individual photo detail views
5. Photo editing and deletion
6. Bulk upload capability
7. Comprehensive test coverage

## Notes for Junior Developer

- The controller handles both single and bulk uploads
- Drag-and-drop uses the Fetch API for AJAX uploads
- Image processing happens asynchronously via Active Storage
- Pagination will be added if you include kaminari gem
- The JavaScript provides visual feedback during uploads

## Validation Steps

1. Upload a single photo via the form
2. Test drag-and-drop with multiple files
3. Verify photo gallery displays correctly
4. Test photo editing and deletion
5. Check responsive behavior on mobile
6. Run test suite: `bundle exec rspec spec/controllers/photos_controller_spec.rb`

## Next Steps

After completing this ticket, you'll move to Phase 4: Family & Sharing System, starting with family models and invitations.