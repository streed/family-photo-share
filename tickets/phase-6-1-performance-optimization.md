# Phase 6, Ticket 1: Performance Optimization and Caching

**Priority**: Medium  
**Estimated Time**: 2-3 hours  
**Prerequisites**: Completed Phase 5  

## Objective

Implement performance optimizations including database query optimization, image processing improvements, caching strategies, and background job processing to ensure the application scales well with growing photo collections.

## Acceptance Criteria

- [ ] Database queries optimized with proper includes and joins
- [ ] Image processing moved to background jobs
- [ ] Redis caching implemented for frequently accessed data
- [ ] Database indexes added for common queries
- [ ] N+1 query issues resolved
- [ ] Image variants cached and optimized
- [ ] Performance monitoring and logging in place
- [ ] Load testing recommendations provided

## Technical Requirements

### 1. Database Query Optimization

Create `app/models/concerns/optimized_queries.rb`:

```ruby
module OptimizedQueries
  extend ActiveSupport::Concern

  class_methods do
    # Optimized scope for loading photos with all necessary associations
    def with_full_includes
      includes(
        :user,
        :albums,
        image_attachment: :blob,
        album_photos: [:album, :added_by]
      )
    end

    # Optimized scope for family photo queries
    def for_family_with_includes(family)
      joins(user: :families)
        .where(families: { id: family.id })
        .with_full_includes
    end
  end
end
```

Update `app/models/photo.rb`:

```ruby
class Photo < ApplicationRecord
  include OptimizedQueries
  
  # ... existing code ...

  # Optimized scopes
  scope :recent_with_includes, -> { recent.with_full_includes }
  scope :for_album_optimized, ->(album) { 
    joins(:album_photos)
      .where(album_photos: { album: album })
      .includes(:user, image_attachment: :blob)
      .order('album_photos.position ASC')
  }

  # Batch operations for better performance
  def self.add_to_album_batch(photo_ids, album, user)
    photos = where(id: photo_ids).includes(:albums)
    
    album_photos_to_create = []
    photos.each do |photo|
      next if photo.albums.include?(album)
      
      album_photos_to_create << {
        album_id: album.id,
        photo_id: photo.id,
        added_by_id: user.id,
        position: album.next_position,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    AlbumPhoto.insert_all(album_photos_to_create) if album_photos_to_create.any?
    album.update_photo_count!
  end

  # Cache expensive operations
  def image_metadata_cached
    Rails.cache.fetch("photo_#{id}_metadata", expires_in: 1.hour) do
      {
        dimensions: image_dimensions,
        file_size: formatted_file_size,
        processed: image_processed?
      }
    end
  end
end
```

Update `app/models/album.rb`:

```ruby
class Album < ApplicationRecord
  include OptimizedQueries

  # ... existing code ...

  # Optimized queries
  def album_photos_optimized
    album_photos.includes(:photo, :added_by, photo: { image_attachment: :blob })
               .ordered
  end

  def photos_with_metadata
    photos.includes(:user, :album_photos, image_attachment: :blob)
          .joins(:album_photos)
          .where(album_photos: { album: self })
          .order('album_photos.position ASC')
  end

  # Cache album statistics
  def stats_cached
    Rails.cache.fetch("album_#{id}_stats", expires_in: 30.minutes) do
      {
        photo_count: photo_count,
        contributor_count: contributors.count,
        latest_photo_date: photos.maximum(:created_at),
        total_file_size: photos.joins(image_attachment: :blob)
                              .sum('active_storage_blobs.byte_size')
      }
    end
  end

  private

  def expire_stats_cache
    Rails.cache.delete("album_#{id}_stats")
  end

  # Add callback to expire cache
  after_update :expire_stats_cache
end
```

### 2. Background Job Processing

Create `app/jobs/image_processing_job.rb`:

```ruby
class ImageProcessingJob < ApplicationJob
  queue_as :default

  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    return unless photo&.image&.attached?

    # Process variants in background
    begin
      # Generate thumbnail
      photo.thumbnail.processed
      
      # Generate medium size
      photo.medium.processed
      
      # Generate large size
      photo.large.processed
      
      # Extract and cache metadata
      if photo.image.blob.analyzed?
        metadata = photo.image.blob.metadata
        photo.update_columns(
          metadata: metadata,
          file_size: photo.image.blob.byte_size,
          content_type: photo.image.blob.content_type
        )
      end

      Rails.logger.info "Image processing completed for Photo #{photo.id}"
    rescue => e
      Rails.logger.error "Image processing failed for Photo #{photo.id}: #{e.message}"
      raise e
    end
  end
end
```

Create `app/jobs/album_stats_update_job.rb`:

```ruby
class AlbumStatsUpdateJob < ApplicationJob
  queue_as :low_priority

  def perform(album_id)
    album = Album.find_by(id: album_id)
    return unless album

    # Update photo count
    actual_count = album.album_photos.count
    album.update_column(:photo_count, actual_count) if album.photo_count != actual_count

    # Expire cached stats
    Rails.cache.delete("album_#{album.id}_stats")

    # Update family stats cache
    Rails.cache.delete("family_#{album.family_id}_stats")
  end
end
```

Create `app/jobs/email_digest_job.rb`:

```ruby
class EmailDigestJob < ApplicationJob
  queue_as :mailers

  def perform(user_id, period = 'weekly')
    user = User.find_by(id: user_id)
    return unless user

    case period
    when 'weekly'
      send_weekly_digest(user)
    when 'monthly'
      send_monthly_digest(user)
    end
  end

  private

  def send_weekly_digest(user)
    families = user.families.includes(:albums, :photos)
    recent_activity = collect_recent_activity(families, 1.week.ago)
    
    if recent_activity.any?
      FamilyDigestMailer.weekly_digest(user, recent_activity).deliver_now
    end
  end

  def send_monthly_digest(user)
    families = user.families.includes(:albums, :photos)
    recent_activity = collect_recent_activity(families, 1.month.ago)
    
    if recent_activity.any?
      FamilyDigestMailer.monthly_digest(user, recent_activity).deliver_now
    end
  end

  def collect_recent_activity(families, since)
    activity = {}
    
    families.each do |family|
      activity[family.id] = {
        family: family,
        new_photos: family.photos.where('created_at > ?', since).count,
        new_albums: family.albums.where('created_at > ?', since).count,
        new_members: family.family_memberships.where('created_at > ?', since).count
      }
    end

    activity.select { |_, data| data[:new_photos] > 0 || data[:new_albums] > 0 || data[:new_members] > 0 }
  end
end
```

Update `app/models/photo.rb` to use background processing:

```ruby
# Update the after_create_commit callback
after_create_commit :process_image_variants_async

private

def process_image_variants_async
  ImageProcessingJob.perform_later(id)
end
```

### 3. Caching Implementation

Create `config/initializers/caching.rb`:

```ruby
# Configure caching strategies
Rails.application.configure do
  # Use Redis for caching in production
  if Rails.env.production?
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
      expires_in: 90.minutes,
      size: 64.megabytes
    }
  elsif Rails.env.development?
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
      expires_in: 30.minutes
    }
  end
end

# Cache key versioning
module CacheHelpers
  def cache_key_for_photos(photos)
    "photos/#{photos.maximum(:updated_at)&.to_i || 0}/#{photos.count}"
  end

  def cache_key_for_album(album)
    "album/#{album.id}/#{album.updated_at.to_i}/#{album.photo_count}"
  end

  def cache_key_for_family(family)
    "family/#{family.id}/#{family.updated_at.to_i}/#{family.member_count}/#{family.album_count}"
  end
end

ActionController::Base.include CacheHelpers
ActionView::Base.include CacheHelpers
```

Create `app/controllers/concerns/cacheable.rb`:

```ruby
module Cacheable
  extend ActiveSupport::Concern

  included do
    before_action :set_cache_headers, only: [:show, :index]
  end

  private

  def set_cache_headers
    if current_user
      expires_in 10.minutes, public: false
    else
      expires_in 1.hour, public: true
    end
  end

  def cache_if_enabled(key, &block)
    if Rails.application.config.action_controller.perform_caching
      Rails.cache.fetch(key, expires_in: 30.minutes, &block)
    else
      yield
    end
  end
end
```

Update `app/controllers/photos_controller.rb`:

```ruby
class PhotosController < ApplicationController
  include Cacheable

  # ... existing code ...

  def index
    @photos = cache_if_enabled("user_#{current_user.id}_photos_#{params[:page] || 1}") do
      current_user.photos.recent_with_includes
                 .page(params[:page])
                 .per(20)
    end
  end

  def show
    @photo_metadata = @photo.image_metadata_cached
  end

  # ... rest of the code ...
end
```

### 4. Database Indexes

Create migration `add_performance_indexes`:

```bash
bundle exec rails generate migration AddPerformanceIndexes
```

```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[7.0]
  def change
    # Photo indexes for common queries
    add_index :photos, [:user_id, :created_at], name: 'index_photos_on_user_and_date'
    add_index :photos, [:taken_at, :created_at], name: 'index_photos_on_taken_and_created'
    
    # Album indexes
    add_index :albums, [:family_id, :privacy_level], name: 'index_albums_on_family_and_privacy'
    add_index :albums, [:created_by_id, :created_at], name: 'index_albums_on_creator_and_date'
    
    # Album photos indexes for ordering and lookup
    add_index :album_photos, [:album_id, :position], name: 'index_album_photos_on_album_and_position'
    add_index :album_photos, [:added_by_id, :created_at], name: 'index_album_photos_on_adder_and_date'
    
    # Family membership indexes
    add_index :family_memberships, [:user_id, :role], name: 'index_family_memberships_on_user_and_role'
    add_index :family_memberships, [:family_id, :joined_at], name: 'index_family_memberships_on_family_and_joined'
    
    # Invitation indexes
    add_index :family_invitations, [:email, :family_id], name: 'index_family_invitations_on_email_and_family'
    add_index :family_invitations, [:expires_at, :accepted_at], name: 'index_family_invitations_on_expiry_and_acceptance'
    
    # Active Storage performance indexes
    add_index :active_storage_attachments, [:record_type, :record_id, :name, :created_at], 
              name: 'index_active_storage_attachments_on_record_and_name_and_created'
  end
end
```

### 5. View Fragment Caching

Update `app/views/albums/index.html.erb`:

```erb
<!-- Cache the albums grid -->
<% cache(cache_key_for_family(@family) + "/albums") do %>
  <% if @albums.any? %>
    <div class="albums-grid">
      <% @albums.each do |album| %>
        <% cache(album) do %>
          <div class="album-card">
            <!-- album card content -->
          </div>
        <% end %>
      <% end %>
    </div>
  <% end %>
<% end %>
```

Update `app/views/photos/index.html.erb`:

```erb
<!-- Cache the photos grid -->
<% cache("user_#{current_user.id}_photos_#{params[:page] || 1}") do %>
  <% if @photos.any? %>
    <div class="photos-grid">
      <% @photos.each do |photo| %>
        <% cache(photo) do %>
          <div class="photo-card">
            <!-- photo card content -->
          </div>
        <% end %>
      <% end %>
    </div>
  <% end %>
<% end %>
```

### 6. Image Optimization

Create `config/initializers/image_processing.rb`:

```ruby
# Image processing optimization
Rails.application.config.to_prepare do
  # Configure variant processor
  Rails.application.config.active_storage.variant_processor = :mini_magick

  # Optimize image variants
  Rails.application.config.active_storage.variants = {
    thumbnail: { resize_to_fill: [200, 200], quality: 85, strip: true },
    medium: { resize_to_fit: [600, 600], quality: 90, strip: true },
    large: { resize_to_fit: [1200, 1200], quality: 95, strip: true }
  }

  # Precompile common variants
  module ActiveStorageVariantPrecompilation
    extend ActiveSupport::Concern

    included do
      after_commit :precompile_variants, on: :create
    end

    private

    def precompile_variants
      return unless image.attached?
      
      ImageProcessingJob.perform_later(id)
    end
  end

  Photo.include ActiveStorageVariantPrecompilation
end

# Image analysis configuration
Rails.application.config.active_storage.analyzers = [
  ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick,
  ActiveStorage::Analyzer::ImageAnalyzer::Vips
]
```

### 7. Monitoring and Logging

Create `app/controllers/concerns/performance_logging.rb`:

```ruby
module PerformanceLogging
  extend ActiveSupport::Concern

  included do
    around_action :log_performance
  end

  private

  def log_performance
    start_time = Time.current
    
    result = yield
    
    duration = Time.current - start_time
    
    if duration > 0.5 # Log slow requests
      Rails.logger.warn "SLOW REQUEST: #{request.method} #{request.path} took #{duration.round(3)}s"
      Rails.logger.warn "  User: #{current_user&.id || 'anonymous'}"
      Rails.logger.warn "  Params: #{params.except('controller', 'action').inspect}"
    end
    
    result
  end
end
```

Create `config/initializers/performance_monitoring.rb`:

```ruby
# Performance monitoring setup
Rails.application.configure do
  # Log database query analysis in development
  if Rails.env.development?
    config.after_initialize do
      Bullet.enable = true
      Bullet.bullet_logger = true
      Bullet.console = true
      Bullet.rails_logger = true
    end
  end

  # Memory and query monitoring
  if Rails.env.production?
    # Add monitoring service configuration here
    # e.g., New Relic, Datadog, etc.
  end
end

# Query analysis
class QueryAnalyzer
  def self.analyze_slow_queries
    if Rails.env.development?
      puts "\n=== SLOW QUERY ANALYSIS ==="
      
      # Family loading optimization
      puts "Family with members and albums:"
      start_time = Time.current
      family = Family.includes(:members, :albums, albums: :photos).first
      puts "Time: #{Time.current - start_time}s"
      
      # Photo loading optimization
      puts "\nRecent photos with associations:"
      start_time = Time.current
      photos = Photo.recent.includes(:user, :albums, image_attachment: :blob).limit(20)
      photos.each { |p| p.user.display_name_or_full_name; p.albums.count }
      puts "Time: #{Time.current - start_time}s"
      
      puts "=== END ANALYSIS ===\n"
    end
  end
end
```

### 8. Sidekiq Configuration

Update `config/initializers/sidekiq.rb`:

```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
  # Configure queues with priorities
  config.queues = %w[critical high default low_priority mailers]
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Cron jobs for background tasks
if Rails.env.production?
  require 'sidekiq-cron'
  
  Sidekiq::Cron::Job.load_from_hash({
    'weekly_digest' => {
      'cron' => '0 9 * * 1', # Every Monday at 9 AM
      'class' => 'EmailDigestJob',
      'args' => ['weekly']
    },
    'cleanup_expired_invitations' => {
      'cron' => '0 2 * * *', # Every day at 2 AM
      'class' => 'CleanupExpiredInvitationsJob'
    }
  })
end
```

## Testing Requirements

### 1. Performance Tests
Create `spec/performance/photo_loading_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Photo Loading Performance', type: :performance do
  let(:family) { create(:family) }
  let(:user) { family.created_by }
  let!(:photos) { create_list(:photo, 50, user: user) }

  it 'loads photos efficiently' do
    expect {
      Photo.recent_with_includes.limit(20).to_a
    }.to perform_under(0.1.seconds)
  end

  it 'loads family photos without N+1 queries' do
    expect {
      family.photos.with_full_includes.each do |photo|
        photo.user.display_name_or_full_name
        photo.albums.count
      end
    }.to perform_under(0.2.seconds)
  end
end
```

### 2. Caching Tests
Create `spec/caching/photo_caching_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Photo Caching', type: :caching do
  let(:photo) { create(:photo) }

  before do
    Rails.cache.clear
  end

  it 'caches photo metadata' do
    expect(photo).to receive(:image_dimensions).once
    
    # First call should hit the database
    metadata1 = photo.image_metadata_cached
    
    # Second call should use cache
    metadata2 = photo.image_metadata_cached
    
    expect(metadata1).to eq(metadata2)
  end

  it 'expires cache when photo is updated' do
    photo.image_metadata_cached
    expect(Rails.cache.exist?("photo_#{photo.id}_metadata")).to be true
    
    photo.touch
    # Cache should still exist until manually expired
    expect(Rails.cache.exist?("photo_#{photo.id}_metadata")).to be true
  end
end
```

## Files to Create/Modify

- `app/models/concerns/optimized_queries.rb` - Query optimization
- `app/jobs/image_processing_job.rb` - Background image processing
- `app/jobs/album_stats_update_job.rb` - Stats updates
- `app/jobs/email_digest_job.rb` - Email digest sending
- `config/initializers/caching.rb` - Caching configuration
- `config/initializers/image_processing.rb` - Image optimization
- `config/initializers/performance_monitoring.rb` - Performance monitoring
- `db/migrate/xxx_add_performance_indexes.rb` - Database indexes
- View templates with fragment caching
- Performance and caching tests

## Deliverables

1. Optimized database queries with proper includes and joins
2. Background job processing for image operations
3. Redis caching for frequently accessed data
4. Database indexes for common query patterns
5. View fragment caching for expensive renders
6. Image processing optimization
7. Performance monitoring and logging
8. Load testing recommendations

## Notes for Junior Developer

- Always use `includes` when you know you'll access associated records
- Background jobs prevent blocking the web request for slow operations
- Caching should be used judiciously - cache invalidation is the hard part
- Database indexes speed up queries but slow down writes
- Monitor performance in production to identify bottlenecks
- Fragment caching works best for expensive-to-render but slowly-changing content

## Load Testing Recommendations

After implementing these optimizations, consider load testing with:

1. **Apache Bench (ab)**: Simple HTTP load testing
2. **siege**: More advanced HTTP/HTTPS load testing
3. **Rails Performance Testing**: Use `rails-perftest` gem
4. **Database Query Analysis**: Use `explain` on slow queries

Example load test commands:
```bash
# Test photo gallery page
ab -n 100 -c 10 http://localhost:3000/photos

# Test album view
siege -c 20 -t 30s http://localhost:3000/families/1/albums/1
```

## Validation Steps

1. Run migrations: `rails db:migrate`
2. Start Redis and Sidekiq
3. Monitor query logs for N+1 issues
4. Test image upload and background processing
5. Verify caching is working with Rails console
6. Run performance tests: `bundle exec rspec spec/performance/`
7. Check Sidekiq web interface for job processing

## Next Steps

After completing this ticket, you'll move to Phase 6, Ticket 2: Security Hardening and Error Handling.