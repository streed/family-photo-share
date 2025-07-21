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
        photos = Photo.where(id: [photo_taken_yesterday.id, photo_taken_last_week.id]).by_date_taken
        expect(photos).to eq([photo_taken_yesterday, photo_taken_last_week])
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