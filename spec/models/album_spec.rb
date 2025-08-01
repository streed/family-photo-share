require 'rails_helper'

RSpec.describe Album, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:cover_photo).class_name('Photo').optional }
    it { should have_many(:album_photos).dependent(:destroy) }
    it { should have_many(:photos).through(:album_photos) }
  end

  describe 'validations' do
    subject { build(:album) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(1000) }
    it { should validate_presence_of(:privacy) }
    it { should validate_inclusion_of(:privacy).in_array(%w[private family public]) }
    it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
  end

  describe 'instance methods' do
    let(:user) { create(:user) }
    let(:album) { create(:album, user: user) }
    let(:photo1) { create(:photo, user: user) }
    let(:photo2) { create(:photo, user: user) }

    describe '#add_photo' do
      it 'adds a photo to the album' do
        expect(album.add_photo(photo1)).to be true
        expect(album.photos).to include(photo1)
      end

      it 'sets the first photo as cover photo' do
        album.add_photo(photo1)
        expect(album.cover_photo).to eq(photo1)
      end

      it 'does not add duplicate photos' do
        album.add_photo(photo1)
        expect(album.add_photo(photo1)).to be false
        expect(album.photo_count).to eq(1)
      end
    end

    describe '#remove_photo' do
      before do
        album.add_photo(photo1)
        album.add_photo(photo2)
      end

      it 'removes a photo from the album' do
        expect(album.remove_photo(photo1)).to be true
        expect(album.photos).not_to include(photo1)
      end

      it 'updates cover photo when removing current cover' do
        album.update!(cover_photo: photo1)
        album.remove_photo(photo1)
        expect(album.reload.cover_photo).to eq(photo2)
      end
    end

    describe '#accessible_by?' do
      let(:other_user) { create(:user) }
      let(:family) { create(:family) }

      it 'allows access to album owner' do
        expect(album.accessible_by?(user)).to be true
      end

      it 'allows access to public albums' do
        album.update!(privacy: 'public')
        expect(album.accessible_by?(other_user)).to be true
      end

      it 'denies access to private albums for non-owners' do
        expect(album.accessible_by?(other_user)).to be false
      end

      context 'with family albums' do
        before { album.update!(privacy: 'family') }

        it 'allows access to users in the same family' do
          create(:family_membership, user: user, family: family)
          create(:family_membership, user: other_user, family: family)
          user.reload
          other_user.reload
          expect(album.accessible_by?(other_user)).to be true
        end

        it 'denies access to users in different families' do
          other_family = create(:family)
          create(:family_membership, user: user, family: family)
          create(:family_membership, user: other_user, family: other_family)
          user.reload
          other_user.reload
          expect(album.accessible_by?(other_user)).to be false
        end

        it 'denies access to users with no family' do
          create(:family_membership, user: user, family: family)
          user.reload
          expect(album.accessible_by?(other_user)).to be false
        end

        it 'denies access when album owner has no family' do
          create(:family_membership, user: other_user, family: family)
          other_user.reload
          expect(album.accessible_by?(other_user)).to be false
        end
      end
    end

    describe '#photo_count' do
      it 'returns the correct number of photos' do
        album.add_photo(photo1)
        album.add_photo(photo2)
        expect(album.photo_count).to eq(2)
      end
    end
  end
end
