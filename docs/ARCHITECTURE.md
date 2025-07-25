# Family Photo Share Architecture

This document describes the architecture and design decisions of the Family Photo Share application.

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Data Model](#data-model)
- [Application Layers](#application-layers)
- [Background Processing](#background-processing)
- [Security Architecture](#security-architecture)
- [File Storage](#file-storage)
- [API Design](#api-design)
- [Performance Considerations](#performance-considerations)
- [Scalability](#scalability)

## Overview

Family Photo Share is a Ruby on Rails application designed for private family photo sharing. It follows a traditional MVC architecture with modern enhancements including background job processing, real-time updates, and cloud storage integration.

### Key Design Principles

- **Privacy First**: All data is private by default with explicit sharing controls
- **Family-Centric**: Organized around family units rather than individual users
- **Scalable**: Designed to handle growing photo collections and family sizes
- **Self-Hosted**: Can be deployed on private infrastructure
- **User-Friendly**: Intuitive interface for all technical skill levels

## System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │     CDN/Proxy   │    │   File Storage  │
│    (Nginx)      │    │    (CloudFlare) │    │   (S3/Local)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
┌─────────────────────────────────────────────────────────────────┐
│                     Application Tier                           │
├─────────────────┬─────────────────┬─────────────────────────────┤
│   Web Server    │   Web Server    │      Background Jobs        │
│   (Rails App)   │   (Rails App)   │       (Sidekiq)            │
│                 │                 │                             │
│  - Controllers  │  - Controllers  │  - Image Processing         │
│  - Models       │  - Models       │  - EXIF Extraction          │
│  - Views        │  - Views        │  - Email Delivery           │
│  - Services     │  - Services     │  - Cleanup Tasks            │
└─────────────────┴─────────────────┴─────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │     Redis       │    │   File System   │
│   (Primary DB)  │    │  (Cache/Queue)  │    │   (Uploads)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Component Responsibilities

#### Web Servers (Rails Application)
- Handle HTTP requests and responses
- Authentication and authorization
- Business logic execution
- Database operations
- API endpoints

#### Background Jobs (Sidekiq)
- Image processing and variant generation
- EXIF metadata extraction
- Email delivery
- Periodic cleanup tasks
- Bulk operations

#### Database (PostgreSQL)
- User and family data
- Photo metadata
- Album organization
- Session management

#### Cache/Queue (Redis)
- Session storage
- Background job queues
- Application caching
- Rate limiting data

#### File Storage
- Original photo files
- Generated image variants
- Temporary processing files

## Data Model

### Core Entities

```ruby
User
├── belongs_to :family
├── has_many :photos
├── has_many :albums
└── has_many :bulk_uploads

Family
├── has_many :users
└── has_many :albums (through users)

Photo
├── belongs_to :user
├── has_many :albums (through album_photos)
├── has_one_attached :image
└── stores EXIF metadata as JSON

Album
├── belongs_to :user
├── has_many :photos (through album_photos)
├── has_many :album_access_sessions
└── privacy controls (private/family/external)

AlbumPhoto (Join Table)
├── belongs_to :album
├── belongs_to :photo
└── position for ordering

BulkUpload
├── belongs_to :user
├── has_many :photos (through bulk_upload_photos)
└── tracks batch upload progress
```

### Database Schema Overview

```sql
-- Core entities
users (id, email, first_name, last_name, family_id, created_at, updated_at)
families (id, name, created_at, updated_at)
photos (id, user_id, title, description, taken_at, latitude, longitude, 
        camera_make, camera_model, metadata, created_at, updated_at)
albums (id, user_id, name, description, privacy, allow_external_access,
        sharing_token, password_digest, created_at, updated_at)

-- Join tables
album_photos (album_id, photo_id, position, added_at)
bulk_upload_photos (bulk_upload_id, photo_id, status)

-- Supporting entities
bulk_uploads (id, user_id, name, status, total_count, processed_count, 
              created_at, updated_at)
album_access_sessions (id, album_id, session_token, ip_address, 
                       expires_at, created_at)
album_view_events (id, album_id, photo_id, event_type, ip_address, 
                   occurred_at)
```

### Key Indexes

```sql
-- Performance indexes
CREATE INDEX idx_photos_user_created ON photos(user_id, created_at DESC);
CREATE INDEX idx_photos_taken_at ON photos(taken_at DESC) WHERE taken_at IS NOT NULL;
CREATE INDEX idx_album_photos_album_position ON album_photos(album_id, position);
CREATE INDEX idx_albums_user_privacy ON albums(user_id, privacy);
CREATE INDEX idx_sessions_token ON album_access_sessions(session_token);
CREATE INDEX idx_sessions_expires ON album_access_sessions(expires_at);

-- Search indexes (for future full-text search)
CREATE INDEX idx_photos_search ON photos USING gin(to_tsvector('english', 
  coalesce(title, '') || ' ' || coalesce(description, '')));
```

## Application Layers

### Controller Layer

Controllers handle HTTP requests and coordinate between services:

```ruby
# app/controllers/photos_controller.rb
class PhotosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_photo, only: [:show, :edit, :update, :destroy]
  before_action :ensure_owner, only: [:edit, :update, :destroy]
  
  def create
    @photo = PhotoUploadService.new(current_user, photo_params).call
    # Handle response...
  end
  
  private
  
  def photo_params
    params.require(:photo).permit(:image, :title, :description)
  end
end
```

### Service Layer

Services contain business logic and coordinate between models:

```ruby
# app/services/photo_upload_service.rb
class PhotoUploadService
  def initialize(user, params)
    @user = user
    @params = params
  end
  
  def call
    photo = create_photo
    queue_processing_jobs(photo)
    photo
  end
  
  private
  
  def create_photo
    @user.photos.create!(@params.merge(
      original_filename: @params[:image].original_filename,
      file_size: @params[:image].size,
      content_type: @params[:image].content_type
    ))
  end
  
  def queue_processing_jobs(photo)
    ProcessPhotoJob.perform_async(photo.id)
    ExtractPhotoMetadataJob.perform_async(photo.id)
  end
end
```

### Model Layer

Models contain data logic and simple business rules:

```ruby
# app/models/album.rb
class Album < ApplicationRecord
  belongs_to :user
  has_many :album_photos, -> { order(:position) }, dependent: :destroy
  has_many :photos, through: :album_photos
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :privacy, inclusion: { in: %w[private family external] }
  
  scope :accessible_by, ->(user) { 
    where(privacy: 'family', user: { family: user.family })
      .or(where(user: user))
  }
  
  def accessible_by?(user)
    return true if self.user == user
    return true if privacy == 'family' && user&.family == self.user.family
    false
  end
end
```

## Background Processing

### Job Queues

Different types of work are separated into dedicated queues:

```ruby
# config/sidekiq.yml
:queues:
  - default          # General application jobs
  - image_processing # CPU-intensive image work
  - bulk_processing  # Large batch operations
  - mailers         # Email delivery
  - cleanup         # Maintenance tasks
```

### Key Background Jobs

#### Image Processing
```ruby
# app/jobs/process_photo_job.rb
class ProcessPhotoJob
  include Sidekiq::Job
  sidekiq_options queue: 'image_processing', retry: 3
  
  def perform(photo_id)
    photo = Photo.find(photo_id)
    ImageProcessingService.new(photo).generate_variants
  end
end
```

#### EXIF Extraction
```ruby
# app/jobs/extract_photo_metadata_job.rb
class ExtractPhotoMetadataJob
  include Sidekiq::Job
  sidekiq_options queue: 'image_processing', retry: 3
  
  def perform(photo_id)
    photo = Photo.find(photo_id)
    ExifExtractionService.new(photo).extract_and_store
  end
end
```

#### Bulk Operations
```ruby
# app/jobs/bulk_upload_processing_job.rb
class BulkUploadProcessingJob
  include Sidekiq::Job
  sidekiq_options queue: 'bulk_processing', retry: 1
  
  def perform(bulk_upload_id)
    bulk_upload = BulkUpload.find(bulk_upload_id)
    BulkUploadService.new(bulk_upload).process_all_photos
  end
end
```

## Security Architecture

### Authentication

- **Primary**: Devise with database sessions
- **External Access**: Temporary token-based sessions for album sharing
- **Rate Limiting**: Progressive lockout for failed login attempts

```ruby
# Rate limiting implementation
class SessionsController < Devise::SessionsController
  MAX_ATTEMPTS = 5
  LOCKOUT_DURATION = 15.minutes
  
  def create
    if rate_limit_exceeded?
      handle_rate_limit
      return
    end
    
    super
  end
  
  private
  
  def rate_limit_exceeded?
    failed_attempts >= MAX_ATTEMPTS && within_lockout_period?
  end
end
```

### Authorization

- **Family-Based**: Users can only access their family's content
- **Owner-Based**: Only photo/album owners can modify content
- **Role-Based**: Different permissions for family admins vs members

```ruby
# Authorization pattern
class AlbumsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_album
  before_action :ensure_access, only: [:show]
  before_action :ensure_owner, only: [:edit, :update, :destroy]
  
  private
  
  def ensure_access
    unless @album.accessible_by?(current_user)
      redirect_to albums_path, alert: 'Access denied'
    end
  end
end
```

### Input Validation

- **File Uploads**: Content type and size validation
- **XSS Prevention**: HTML sanitization
- **SQL Injection**: Parameterized queries only
- **CSRF Protection**: Rails built-in protection enabled

## File Storage

### Storage Abstraction

```ruby
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['AWS_REGION'] %>
  bucket: <%= ENV['AWS_BUCKET'] %>
```

### Image Variants

Multiple variants are generated for different use cases:

```ruby
# app/services/image_processing_service.rb
class ImageProcessingService
  VARIANTS = {
    thumbnail: { resize_to_limit: [150, 150] },
    small: { resize_to_limit: [300, 300] },
    medium: { resize_to_limit: [600, 600] },
    large: { resize_to_limit: [1200, 1200] }
  }.freeze
  
  def generate_variants
    VARIANTS.each do |name, options|
      @photo.image.variant(options).processed
    end
  end
end
```

## API Design

### RESTful Endpoints

Following Rails conventions with some extensions:

```
GET    /photos           # List photos
POST   /photos           # Create photo
GET    /photos/:id       # Show photo
PATCH  /photos/:id       # Update photo
DELETE /photos/:id       # Delete photo

GET    /albums           # List albums
POST   /albums           # Create album
GET    /albums/:id       # Show album
PATCH  /albums/:id       # Update album
DELETE /albums/:id       # Delete album

# Nested resources for album management
PATCH  /albums/:id/add_photo    # Add photo to album
DELETE /albums/:id/remove_photo # Remove photo from album
PATCH  /albums/:id/set_cover    # Set cover photo
```

### Error Handling

Consistent error responses across the application:

```ruby
# app/controllers/concerns/error_handling.rb
module ErrorHandling
  extend ActiveSupport::Concern
  
  included do
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :bad_request
  end
  
  private
  
  def not_found(exception)
    render json: { error: 'Resource not found' }, status: :not_found
  end
  
  def unprocessable_entity(exception)
    render json: { 
      error: 'Validation failed',
      details: exception.record.errors
    }, status: :unprocessable_entity
  end
end
```

## Performance Considerations

### Database Optimization

- **Eager Loading**: Use `includes` to prevent N+1 queries
- **Indexes**: Strategic indexes on frequently queried columns
- **Pagination**: Limit large result sets
- **Connection Pooling**: Configured for concurrent access

```ruby
# Optimized photo loading
def index
  @photos = current_user.photos
                       .includes(:user, :albums)
                       .order(created_at: :desc)
                       .page(params[:page])
                       .per(20)
end
```

### Caching Strategy

- **Fragment Caching**: Cache expensive view fragments
- **Low-Level Caching**: Cache computed values
- **HTTP Caching**: Leverage browser caching for assets

```ruby
# View caching example
<% cache [@album, @album.photos.maximum(:updated_at)] do %>
  <%= render partial: 'photo', collection: @album.photos %>
<% end %>
```

### Image Optimization

- **Lazy Variant Generation**: Create variants on-demand
- **CDN Integration**: Serve images through CDN
- **WebP Support**: Modern image formats when supported

## Scalability

### Horizontal Scaling

The application is designed to scale horizontally:

- **Stateless Web Servers**: Session data in Redis
- **Background Job Scaling**: Add more Sidekiq workers
- **Database Read Replicas**: Separate read/write workloads
- **File Storage**: Cloud storage scales automatically

### Vertical Scaling Considerations

- **Memory Usage**: Monitor Rails memory consumption
- **CPU Usage**: Image processing is CPU-intensive
- **Disk I/O**: Consider SSD storage for databases
- **Network**: High bandwidth for image uploads/downloads

### Monitoring and Observability

```ruby
# Health check endpoint
class HealthController < ApplicationController
  def show
    render json: {
      status: :ok,
      database: database_healthy?,
      redis: redis_healthy?,
      storage: storage_healthy?,
      workers: sidekiq_healthy?
    }
  end
end
```

### Future Scaling Considerations

- **Microservices**: Extract image processing service
- **Event Sourcing**: For audit trails and analytics
- **CQRS**: Separate read/write models
- **Sharding**: Database sharding by family_id

This architecture provides a solid foundation for a family photo sharing application that can grow with user needs while maintaining performance and security.