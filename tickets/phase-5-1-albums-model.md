# Phase 5, Ticket 1: Albums Model and Photo Organization

**Priority**: High  
**Estimated Time**: 3-4 hours  
**Prerequisites**: Completed Phase 4  

## Objective

Create the Album model with photo organization capabilities, allowing users to create albums, add photos to multiple albums, and manage album access within families.

## Acceptance Criteria

- [ ] Album model created with necessary attributes
- [ ] Many-to-many relationship between Photos and Albums
- [ ] Album creation and management functionality
- [ ] Photo assignment to albums
- [ ] Album privacy and sharing controls
- [ ] Album cover photo selection
- [ ] Bulk photo operations for albums
- [ ] Comprehensive test coverage

## Technical Requirements

### 1. Create Album Model
```bash
bundle exec rails generate model Album title:string description:text family:references created_by:references cover_photo:references
```

Update the migration:
```ruby
class CreateAlbums < ActiveRecord::Migration[7.0]
  def change
    create_table :albums do |t|
      t.string :title, null: false
      t.text :description
      t.references :family, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :cover_photo, foreign_key: { to_table: :photos }, null: true
      t.string :privacy_level, default: 'family'
      t.string :passcode
      t.datetime :passcode_expires_at
      t.integer :photo_count, default: 0

      t.timestamps
    end

    add_index :albums, [:family_id, :created_at]
    add_index :albums, :privacy_level
    add_index :albums, :passcode, unique: true, where: "passcode IS NOT NULL"
  end
end
```

### 2. Create AlbumPhoto Join Model
```bash
bundle exec rails generate model AlbumPhoto album:references photo:references added_by:references position:integer
```

Update the migration:
```ruby
class CreateAlbumPhotos < ActiveRecord::Migration[7.0]
  def change
    create_table :album_photos do |t|
      t.references :album, null: false, foreign_key: true
      t.references :photo, null: false, foreign_key: true
      t.references :added_by, null: false, foreign_key: { to_table: :users }
      t.integer :position, default: 0
      t.text :caption

      t.timestamps
    end

    add_index :album_photos, [:album_id, :photo_id], unique: true
    add_index :album_photos, [:album_id, :position]
    add_index :album_photos, :photo_id
  end
end
```

### 3. Update Album Model
Update `app/models/album.rb`:

```ruby
class Album < ApplicationRecord
  belongs_to :family
  belongs_to :created_by, class_name: 'User'
  belongs_to :cover_photo, class_name: 'Photo', optional: true
  
  has_many :album_photos, dependent: :destroy
  has_many :photos, through: :album_photos
  
  # Privacy levels
  PRIVACY_LEVELS = %w[family private passcode_protected].freeze
  
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }
  validates :privacy_level, inclusion: { in: PRIVACY_LEVELS }
  validates :passcode, presence: true, if: :passcode_protected?
  validates :passcode, length: { minimum: 4, maximum: 20 }, allow_blank: true
  validates :passcode, uniqueness: true, allow_blank: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_title, -> { order(:title) }
  scope :family_visible, -> { where(privacy_level: ['family']) }
  scope :with_photos, -> { where('photo_count > 0') }

  # Callbacks
  before_save :set_passcode_expiry, if: :passcode_protected?
  after_update :update_photo_count_cache

  # Privacy methods
  def family?
    privacy_level == 'family'
  end

  def private?
    privacy_level == 'private'
  end

  def passcode_protected?
    privacy_level == 'passcode_protected'
  end

  # Access control
  def accessible_by?(user, entered_passcode = nil)
    return false unless user

    # Creator always has access
    return true if created_by == user

    # Family member access
    if family?
      return family.user_can_view?(user)
    end

    # Private albums only accessible by creator
    if private?
      return false
    end

    # Passcode protected albums
    if passcode_protected?
      return false unless entered_passcode
      return false if passcode_expired?
      return entered_passcode == passcode
    end

    false
  end

  def editable_by?(user)
    return false unless user
    return true if created_by == user
    return family.user_can_edit?(user) if family?
    false
  end

  # Passcode management
  def passcode_expired?
    passcode_expires_at.present? && passcode_expires_at < Time.current
  end

  def generate_passcode!
    loop do
      self.passcode = SecureRandom.hex(4).upcase
      break unless Album.exists?(passcode: passcode)
    end
    set_passcode_expiry
    save!
  end

  def clear_passcode!
    self.passcode = nil
    self.passcode_expires_at = nil
    save!
  end

  # Photo management
  def add_photo(photo, user)
    return false unless photo.user.member_of?(family) || editable_by?(user)
    return false if photos.include?(photo)

    album_photos.create!(
      photo: photo,
      added_by: user,
      position: next_position
    )
    
    update_photo_count!
    set_cover_photo_if_needed(photo)
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def remove_photo(photo)
    album_photo = album_photos.find_by(photo: photo)
    return false unless album_photo

    album_photo.destroy
    update_photo_count!
    update_cover_photo_if_needed(photo)
    true
  end

  def reorder_photos(photo_ids)
    photo_ids.each_with_index do |photo_id, index|
      album_photos.find_by(photo_id: photo_id)&.update(position: index)
    end
  end

  # Cover photo management
  def set_cover_photo!(photo)
    return false unless photos.include?(photo)
    update(cover_photo: photo)
  end

  def cover_photo_or_first
    cover_photo || photos.first
  end

  # Statistics
  def photo_count_actual
    album_photos.count
  end

  def latest_photos(limit = 6)
    photos.joins(:album_photos)
          .where(album_photos: { album: self })
          .order('album_photos.created_at DESC')
          .limit(limit)
          .includes(image_attachment: :blob)
  end

  def contributors
    User.joins(:album_photos)
        .where(album_photos: { album: self })
        .distinct
  end

  private

  def next_position
    (album_photos.maximum(:position) || -1) + 1
  end

  def set_passcode_expiry
    self.passcode_expires_at = 30.days.from_now if passcode_protected?
  end

  def update_photo_count!
    update_column(:photo_count, album_photos.count)
  end

  def update_photo_count_cache
    update_photo_count! if saved_change_to_attribute?(:privacy_level)
  end

  def set_cover_photo_if_needed(photo)
    update(cover_photo: photo) if cover_photo.nil?
  end

  def update_cover_photo_if_needed(removed_photo)
    if cover_photo == removed_photo
      new_cover = photos.first
      update(cover_photo: new_cover)
    end
  end
end
```

### 4. Update AlbumPhoto Model
Update `app/models/album_photo.rb`:

```ruby
class AlbumPhoto < ApplicationRecord
  belongs_to :album
  belongs_to :photo
  belongs_to :added_by, class_name: 'User'

  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :photo_id, uniqueness: { scope: :album_id, message: "is already in this album" }
  validates :caption, length: { maximum: 500 }

  scope :ordered, -> { order(:position) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  after_create :update_album_photo_count
  after_destroy :update_album_photo_count

  def next
    album.album_photos.where('position > ?', position).ordered.first
  end

  def previous
    album.album_photos.where('position < ?', position).order(position: :desc).first
  end

  private

  def update_album_photo_count
    album.update_photo_count!
  end
end
```

### 5. Update Photo Model
Update `app/models/photo.rb` to add album associations:

```ruby
class Photo < ApplicationRecord
  # ... existing code ...

  # Album associations
  has_many :album_photos, dependent: :destroy
  has_many :albums, through: :album_photos
  has_many :cover_albums, class_name: 'Album', foreign_key: 'cover_photo_id'

  # ... existing code ...

  # Album-related methods
  def in_album?(album)
    albums.include?(album)
  end

  def album_count
    albums.count
  end

  def family_albums
    albums.joins(:family).where(families: { id: user.family_ids })
  end

  def accessible_albums_for(user)
    albums.select { |album| album.accessible_by?(user) }
  end

  # Get caption for specific album
  def caption_in_album(album)
    album_photos.find_by(album: album)&.caption
  end

  # Get position in specific album
  def position_in_album(album)
    album_photos.find_by(album: album)&.position
  end
end
```

### 6. Update Family Model
Update `app/models/family.rb` to add album associations:

```ruby
class Family < ApplicationRecord
  # ... existing code ...

  # Album associations
  has_many :albums, dependent: :destroy

  # ... existing code ...

  # Album-related methods
  def album_count
    albums.count
  end

  def recent_albums(limit = 5)
    albums.recent.limit(limit)
  end

  def albums_with_photos
    albums.with_photos.recent
  end
end
```

### 7. Update User Model
Update `app/models/user.rb` to add album associations:

```ruby
class User < ApplicationRecord
  # ... existing code ...

  # Album associations
  has_many :created_albums, class_name: 'Album', foreign_key: 'created_by_id', dependent: :destroy
  has_many :album_photos, foreign_key: 'added_by_id', dependent: :destroy

  # ... existing code ...

  # Album-related methods
  def album_count
    created_albums.count
  end

  def accessible_albums
    family_ids = families.pluck(:id)
    Album.joins(:family)
         .where(families: { id: family_ids })
         .where(privacy_level: 'family')
         .or(Album.where(created_by: self))
  end

  def recent_albums(limit = 5)
    accessible_albums.recent.limit(limit)
  end
end
```

### 8. Create Albums Controller
Create `app/controllers/albums_controller.rb`:

```ruby
class AlbumsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_album, only: [:show, :edit, :update, :destroy, :add_photos, :remove_photo, :reorder_photos]
  before_action :set_family, only: [:index, :new, :create]
  before_action :check_album_access, only: [:show]
  before_action :check_album_edit_permission, only: [:edit, :update, :destroy, :add_photos, :remove_photo, :reorder_photos]

  def index
    @albums = @family.albums.recent.includes(:cover_photo, :created_by)
    @can_create_albums = @family.user_can_edit?(current_user)
  end

  def show
    @album_photos = @album.album_photos.includes(:photo, :added_by)
                           .joins(:photo).includes(photo: { image_attachment: :blob })
                           .ordered
    @can_edit = @album.editable_by?(current_user)
    @available_photos = current_user.photos.where.not(id: @album.photo_ids) if @can_edit
  end

  def new
    @album = @family.albums.build(created_by: current_user)
  end

  def create
    @album = @family.albums.build(album_params)
    @album.created_by = current_user

    if @album.save
      redirect_to [@album.family, @album], notice: 'Album created successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Edit album details
  end

  def update
    if @album.update(album_params)
      redirect_to [@album.family, @album], notice: 'Album updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    family = @album.family
    @album.destroy
    redirect_to family_albums_path(family), notice: 'Album deleted successfully!'
  end

  # Add photos to album
  def add_photos
    photo_ids = params[:photo_ids] || []
    added_count = 0

    photo_ids.each do |photo_id|
      photo = current_user.photos.find_by(id: photo_id)
      if photo && @album.add_photo(photo, current_user)
        added_count += 1
      end
    end

    if added_count > 0
      redirect_to [@album.family, @album], 
                  notice: "#{added_count} #{'photo'.pluralize(added_count)} added to album."
    else
      redirect_to [@album.family, @album], 
                  alert: "No photos were added to the album."
    end
  end

  # Remove photo from album
  def remove_photo
    photo = @album.photos.find(params[:photo_id])
    
    if @album.remove_photo(photo)
      redirect_to [@album.family, @album], notice: 'Photo removed from album.'
    else
      redirect_to [@album.family, @album], alert: 'Failed to remove photo from album.'
    end
  end

  # Reorder photos in album
  def reorder_photos
    @album.reorder_photos(params[:photo_ids])
    render json: { success: true }
  end

  # Set cover photo
  def set_cover_photo
    photo = @album.photos.find(params[:photo_id])
    
    if @album.set_cover_photo!(photo)
      redirect_to [@album.family, @album], notice: 'Cover photo updated.'
    else
      redirect_to [@album.family, @album], alert: 'Failed to update cover photo.'
    end
  end

  # Access album with passcode
  def access_with_passcode
    if params[:passcode] && @album.accessible_by?(current_user, params[:passcode])
      session["album_#{@album.id}_access"] = true
      redirect_to [@album.family, @album]
    else
      redirect_to [@album.family, @album], alert: 'Invalid passcode.'
    end
  end

  private

  def set_album
    @album = Album.find(params[:id])
  end

  def set_family
    @family = Family.find(params[:family_id]) if params[:family_id]
  end

  def check_album_access
    unless @album.accessible_by?(current_user) || session["album_#{@album.id}_access"]
      if @album.passcode_protected?
        render :passcode_required
      else
        redirect_to families_path, alert: 'You do not have access to this album.'
      end
    end
  end

  def check_album_edit_permission
    unless @album.editable_by?(current_user)
      redirect_to [@album.family, @album], alert: 'You do not have permission to edit this album.'
    end
  end

  def album_params
    params.require(:album).permit(:title, :description, :privacy_level, :passcode)
  end
end
```

## Testing Requirements

### 1. Create Album Factory
Create `spec/factories/albums.rb`:

```ruby
FactoryBot.define do
  factory :album do
    title { Faker::Lorem.words(number: 3).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    association :family
    association :created_by, factory: :user
    privacy_level { 'family' }

    trait :private do
      privacy_level { 'private' }
    end

    trait :passcode_protected do
      privacy_level { 'passcode_protected' }
      passcode { 'TEST123' }
      passcode_expires_at { 30.days.from_now }
    end

    trait :with_photos do
      after(:create) do |album|
        photos = create_list(:photo, 3, user: album.created_by)
        photos.each { |photo| album.add_photo(photo, album.created_by) }
      end
    end
  end
end
```

Create `spec/factories/album_photos.rb`:

```ruby
FactoryBot.define do
  factory :album_photo do
    association :album
    association :photo
    association :added_by, factory: :user
    position { 0 }
    caption { Faker::Lorem.sentence }
  end
end
```

### 2. Create Album Model Tests
Create `spec/models/album_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Album, type: :model do
  describe 'associations' do
    it { should belong_to(:family) }
    it { should belong_to(:created_by).class_name('User') }
    it { should belong_to(:cover_photo).class_name('Photo').optional }
    it { should have_many(:album_photos).dependent(:destroy) }
    it { should have_many(:photos).through(:album_photos) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(1000) }
    it { should validate_inclusion_of(:privacy_level).in_array(Album::PRIVACY_LEVELS) }

    context 'when passcode protected' do
      subject { build(:album, :passcode_protected) }
      
      it { should validate_presence_of(:passcode) }
      it { should validate_length_of(:passcode).is_at_least(4).is_at_most(20) }
    end
  end

  describe 'privacy methods' do
    let(:family_album) { create(:album, privacy_level: 'family') }
    let(:private_album) { create(:album, privacy_level: 'private') }
    let(:passcode_album) { create(:album, :passcode_protected) }

    it 'correctly identifies privacy levels' do
      expect(family_album.family?).to be true
      expect(private_album.private?).to be true
      expect(passcode_album.passcode_protected?).to be true
    end
  end

  describe '#accessible_by?' do
    let(:family) { create(:family) }
    let(:album) { create(:album, family: family) }
    let(:family_member) { create(:user) }
    let(:outsider) { create(:user) }

    before do
      family.add_member(family_member, role: 'viewer')
    end

    context 'family album' do
      it 'allows access to family members' do
        expect(album.accessible_by?(family_member)).to be true
      end

      it 'denies access to non-family members' do
        expect(album.accessible_by?(outsider)).to be false
      end
    end

    context 'passcode protected album' do
      let(:passcode_album) { create(:album, :passcode_protected, family: family) }

      it 'allows access with correct passcode' do
        expect(passcode_album.accessible_by?(outsider, 'TEST123')).to be true
      end

      it 'denies access with incorrect passcode' do
        expect(passcode_album.accessible_by?(outsider, 'WRONG')).to be false
      end
    end
  end

  describe '#add_photo' do
    let(:album) { create(:album) }
    let(:photo) { create(:photo, user: album.created_by) }

    it 'adds photo to album successfully' do
      expect {
        album.add_photo(photo, album.created_by)
      }.to change(album.photos, :count).by(1)
    end

    it 'sets cover photo if none exists' do
      album.add_photo(photo, album.created_by)
      expect(album.cover_photo).to eq(photo)
    end

    it 'updates photo count' do
      album.add_photo(photo, album.created_by)
      expect(album.reload.photo_count).to eq(1)
    end
  end

  describe '#remove_photo' do
    let(:album) { create(:album, :with_photos) }
    let(:photo) { album.photos.first }

    it 'removes photo from album' do
      expect {
        album.remove_photo(photo)
      }.to change(album.photos, :count).by(-1)
    end

    it 'updates photo count' do
      original_count = album.photo_count
      album.remove_photo(photo)
      expect(album.reload.photo_count).to eq(original_count - 1)
    end
  end
end
```

## Files to Create/Modify

- `db/migrate/xxx_create_albums.rb` - Album table
- `db/migrate/xxx_create_album_photos.rb` - Album-Photo join table  
- `app/models/album.rb` - Album model with privacy controls
- `app/models/album_photo.rb` - Join model with positioning
- `app/models/photo.rb` - Add album associations
- `app/models/family.rb` - Add album associations
- `app/models/user.rb` - Add album associations
- `app/controllers/albums_controller.rb` - Album management
- `spec/factories/albums.rb` - Album factory
- `spec/factories/album_photos.rb` - AlbumPhoto factory
- `spec/models/album_spec.rb` - Album model tests

## Deliverables

1. Complete album management system
2. Photo organization and assignment to albums
3. Privacy controls (family, private, passcode-protected)
4. Album cover photo management
5. Photo positioning and reordering within albums
6. Comprehensive test coverage

## Notes for Junior Developer

- Albums can have three privacy levels: family (visible to all family members), private (only creator), and passcode-protected (anyone with passcode)
- Photos can belong to multiple albums simultaneously
- The AlbumPhoto join model allows for album-specific metadata like captions and positioning
- Cover photos are automatically set to the first photo if none is explicitly chosen
- Passcode-protected albums allow temporary sharing outside the family

## Validation Steps

1. Run migrations: `rails db:migrate`
2. Create an album in Rails console
3. Add photos to the album
4. Test privacy controls
5. Verify photo positioning works
6. Run test suite: `bundle exec rspec spec/models/album_spec.rb`

## Next Steps

After completing this ticket, you'll move to Phase 5, Ticket 2: Album Views and Photo Management Interface.