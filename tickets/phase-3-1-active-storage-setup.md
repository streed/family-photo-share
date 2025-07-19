# Phase 3, Ticket 1: Active Storage Setup and Photo Model

**Priority**: High  
**Estimated Time**: 2-3 hours  
**Prerequisites**: Completed Phase 2  

## Objective

Set up Active Storage for file uploads and create the Photo model with proper associations and validations for handling photo uploads.

## Acceptance Criteria

- [ ] Active Storage properly configured and installed
- [ ] Photo model created with necessary attributes
- [ ] User-Photo association established
- [ ] Image processing configured for thumbnails and variants
- [ ] Basic photo upload validation
- [ ] File storage working in development environment
- [ ] Tests for Photo model functionality

## Technical Requirements

### 1. Install and Configure Active Storage
```bash
bundle exec rails active_storage:install
bundle exec rails db:migrate
```

### 2. Configure Active Storage
Update `config/storage.yml`:

```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

# Future cloud storage options
# amazon:
#   service: S3
#   access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
#   secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
#   region: us-east-1
#   bucket: your_own_bucket
```

Update `config/environments/development.rb`:
```ruby
# Store uploaded files on the local file system
config.active_storage.variant_processor = :mini_magick
config.active_storage.service = :local
```

Update `config/environments/test.rb`:
```ruby
# Store uploaded files on the local file system in a temporary directory
config.active_storage.service = :test
```

### 3. Create Photo Model
```bash
bundle exec rails generate model Photo title:string description:text user:references taken_at:datetime location:string
```

Update the migration file:
```ruby
class CreatePhotos < ActiveRecord::Migration[7.0]
  def change
    create_table :photos do |t|
      t.string :title, null: false
      t.text :description
      t.references :user, null: false, foreign_key: true
      t.datetime :taken_at
      t.string :location
      t.string :original_filename
      t.integer :file_size
      t.string :content_type
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :photos, :taken_at
    add_index :photos, :created_at
  end
end
```

### 4. Update Photo Model
Update `app/models/photo.rb`:

```ruby
class Photo < ApplicationRecord
  belongs_to :user

  # Active Storage associations
  has_one_attached :image

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validates :location, length: { maximum: 255 }
  validates :image, presence: true, content_type: ['image/png', 'image/jpg', 'image/jpeg', 'image/gif'],
                    size: { less_than: 10.megabytes }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_taken, -> { order(taken_at: :desc, created_at: :desc) }

  # Callbacks
  before_save :extract_image_metadata
  after_create_commit :process_image_variants

  # Image variants for different display sizes
  def thumbnail
    image.variant(resize_to_limit: [200, 200])
  end

  def medium
    image.variant(resize_to_limit: [600, 600])
  end

  def large
    image.variant(resize_to_limit: [1200, 1200])
  end

  # Check if image processing is complete
  def image_processed?
    image.attached? && image.blob.analyzed?
  end

  # Get image dimensions if available
  def image_dimensions
    return nil unless image_processed?
    
    metadata = image.blob.metadata
    return nil unless metadata['width'] && metadata['height']
    
    "#{metadata['width']} × #{metadata['height']}"
  end

  # Get formatted file size
  def formatted_file_size
    return nil unless file_size

    if file_size < 1.megabyte
      "#{(file_size / 1.kilobyte.to_f).round(1)} KB"
    else
      "#{(file_size / 1.megabyte.to_f).round(1)} MB"
    end
  end

  private

  def extract_image_metadata
    return unless image.attached?

    self.original_filename = image.blob.filename.to_s
    self.file_size = image.blob.byte_size
    self.content_type = image.blob.content_type

    # Extract EXIF data if available (after blob is analyzed)
    if image.blob.analyzed?
      self.metadata = image.blob.metadata
      
      # Try to extract date taken from EXIF data
      if metadata['date_time_original'].present?
        self.taken_at ||= Time.zone.parse(metadata['date_time_original']) rescue nil
      end
    end
  end

  def process_image_variants
    # Process variants in background job (we'll add this in a later ticket)
    # For now, variants will be processed on-demand
  end
end
```

### 5. Update User Model
Update `app/models/user.rb` to add photo association:

```ruby
class User < ApplicationRecord
  # ... existing code ...

  # Associations
  has_many :photos, dependent: :destroy

  # ... existing code ...

  # Photo-related methods
  def recent_photos(limit = 10)
    photos.recent.limit(limit)
  end

  def photo_count
    photos.count
  end
end
```

### 6. Configure Image Processing
Ensure `image_processing` gem is in your Gemfile (already added in Phase 1):

Create `config/initializers/image_processing.rb`:

```ruby
# Configure image processing
if Rails.env.development? || Rails.env.test?
  # Use mini_magick in development and test
  Rails.application.config.active_storage.variant_processor = :mini_magick
end

# Set up image analysis
Rails.application.config.active_storage.analyze_images = true

# Configure image quality and optimization
Rails.application.config.active_storage.variant_processor = :mini_magick
```

### 7. Create Photo Upload Helper
Create `app/helpers/photos_helper.rb`:

```ruby
module PhotosHelper
  def photo_url(photo, variant = :medium)
    return nil unless photo&.image&.attached?

    case variant
    when :thumbnail
      photo.thumbnail
    when :medium
      photo.medium
    when :large
      photo.large
    else
      photo.image
    end
  end

  def photo_tag(photo, variant = :medium, **options)
    return content_tag(:div, "No image", class: "no-image") unless photo&.image&.attached?

    options[:alt] ||= photo.title
    options[:class] = [options[:class], "photo-image", "photo-#{variant}"].compact.join(" ")

    if photo.image_processed?
      image_tag(photo_url(photo, variant), options)
    else
      content_tag(:div, "Processing...", class: "photo-processing")
    end
  end

  def formatted_photo_date(photo)
    date = photo.taken_at || photo.created_at
    date.strftime("%B %d, %Y at %I:%M %p")
  end
end
```

## Testing Requirements

### 1. Create Photo Factory
Create `spec/factories/photos.rb`:

```ruby
FactoryBot.define do
  factory :photo do
    association :user
    title { Faker::Lorem.words(number: 3).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    taken_at { Faker::Date.between(from: 1.year.ago, to: Date.current) }
    location { Faker::Address.city }

    # Attach a test image file
    after(:build) do |photo|
      photo.image.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg')),
        filename: 'test_image.jpg',
        content_type: 'image/jpeg'
      )
    end

    trait :with_long_description do
      description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    end

    trait :recent do
      taken_at { 1.day.ago }
    end

    trait :old do
      taken_at { 1.year.ago }
    end
  end
end
```

### 2. Create Test Image Fixture
Create the directory structure and add a test image:

```bash
mkdir -p spec/fixtures/files
```

You'll need to add a small test JPEG image file to `spec/fixtures/files/test_image.jpg`. For testing purposes, create a simple 100x100 pixel image.

### 3. Create Photo Model Tests
Create `spec/models/photo_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Photo, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:photo) }

    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_length_of(:description).is_at_most(1000) }
    it { should validate_length_of(:location).is_at_most(255) }

    it 'validates image presence' do
      photo = build(:photo)
      photo.image.purge
      expect(photo).not_to be_valid
      expect(photo.errors[:image]).to include("can't be blank")
    end

    it 'validates image content type' do
      photo = build(:photo)
      photo.image.attach(
        io: StringIO.new("fake content"),
        filename: 'test.txt',
        content_type: 'text/plain'
      )
      expect(photo).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:recent_photo) { create(:photo, created_at: 1.day.ago) }
    let!(:old_photo) { create(:photo, created_at: 1.week.ago) }

    describe '.recent' do
      it 'orders photos by creation date descending' do
        expect(Photo.recent).to eq([recent_photo, old_photo])
      end
    end

    describe '.by_date_taken' do
      let!(:photo_taken_yesterday) { create(:photo, taken_at: 1.day.ago) }
      let!(:photo_taken_last_week) { create(:photo, taken_at: 1.week.ago) }

      it 'orders photos by taken date descending' do
        expect(Photo.by_date_taken.first(2)).to eq([photo_taken_yesterday, photo_taken_last_week])
      end
    end
  end

  describe 'methods' do
    let(:photo) { create(:photo, title: 'Test Photo') }

    describe '#formatted_file_size' do
      it 'returns nil when file_size is nil' do
        photo.update_column(:file_size, nil)
        expect(photo.formatted_file_size).to be_nil
      end

      it 'formats file size in KB for small files' do
        photo.update_column(:file_size, 500.kilobytes)
        expect(photo.formatted_file_size).to eq('500.0 KB')
      end

      it 'formats file size in MB for large files' do
        photo.update_column(:file_size, 2.megabytes)
        expect(photo.formatted_file_size).to eq('2.0 MB')
      end
    end

    describe 'image variants' do
      it 'can create thumbnail variant' do
        expect(photo.thumbnail).to be_a(ActiveStorage::VariantWithRecord)
      end

      it 'can create medium variant' do
        expect(photo.medium).to be_a(ActiveStorage::VariantWithRecord)
      end

      it 'can create large variant' do
        expect(photo.large).to be_a(ActiveStorage::VariantWithRecord)
      end
    end
  end

  describe 'callbacks' do
    it 'extracts metadata before save' do
      photo = build(:photo, original_filename: nil)
      photo.save!
      
      expect(photo.original_filename).to eq('test_image.jpg')
      expect(photo.content_type).to eq('image/jpeg')
      expect(photo.file_size).to be > 0
    end
  end
end
```

### 4. Update User Model Tests
Update `spec/models/user_spec.rb` to include photo associations:

```ruby
# Add to existing user_spec.rb

describe 'associations' do
  it { should have_many(:photos).dependent(:destroy) }
end

describe 'photo methods' do
  let(:user) { create(:user) }
  let!(:photos) { create_list(:photo, 3, user: user) }

  describe '#photo_count' do
    it 'returns the number of photos' do
      expect(user.photo_count).to eq(3)
    end
  end

  describe '#recent_photos' do
    it 'returns recent photos limited by parameter' do
      expect(user.recent_photos(2)).to have(2).items
    end
  end
end
```

## Files to Create/Modify

- `db/migrate/xxx_create_active_storage_tables.rb` - Active Storage tables
- `db/migrate/xxx_create_photos.rb` - Photo model migration
- `app/models/photo.rb` - Photo model with validations
- `app/models/user.rb` - Add photo associations
- `config/storage.yml` - Storage configuration
- `config/environments/development.rb` - Development storage config
- `config/initializers/image_processing.rb` - Image processing setup
- `app/helpers/photos_helper.rb` - Photo display helpers
- `spec/factories/photos.rb` - Photo factory
- `spec/models/photo_spec.rb` - Photo model tests
- `spec/fixtures/files/test_image.jpg` - Test image file

## Deliverables

1. Fully configured Active Storage for file uploads
2. Photo model with proper validations and associations
3. Image variant processing for different sizes
4. Helper methods for photo display
5. Comprehensive test coverage including file uploads

## Notes for Junior Developer

- Active Storage handles file uploads and storage seamlessly
- Image variants are processed on-demand by default (more efficient)
- The `image_processing` gem uses ImageMagick or libvips for image manipulation
- EXIF data extraction helps automatically set photo taken dates
- File size and content type validations prevent abuse

## Validation Steps

1. Run migrations: `rails db:migrate`
2. Check Active Storage tables were created
3. Test photo creation in Rails console
4. Verify image variants can be generated
5. Run test suite: `bundle exec rspec spec/models/photo_spec.rb`
6. Check that test image fixture exists and is accessible

## Common Issues and Solutions

- **ImageMagick not found**: Install ImageMagick via your system package manager
- **Test image missing**: Create a small JPEG file in spec/fixtures/files/
- **Variant processing errors**: Ensure image_processing gem is properly installed

## Next Steps

After completing this ticket, you'll move to Phase 3, Ticket 2: Photo Upload Controller and Views.