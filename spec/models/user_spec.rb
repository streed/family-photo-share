require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_length_of(:first_name).is_at_most(50) }
    it { should validate_length_of(:last_name).is_at_most(50) }
    it { should validate_length_of(:display_name).is_at_most(50) }
    it { should validate_length_of(:bio).is_at_most(500) }
  end

  describe 'methods' do
    let(:user) { create(:user, first_name: 'John', last_name: 'Doe') }

    describe '#full_name' do
      it 'returns the full name' do
        expect(user.full_name).to eq('John Doe')
      end
    end

    describe '#display_name_or_full_name' do
      context 'when display_name is present' do
        before { user.update(display_name: 'Johnny') }

        it 'returns the display name' do
          expect(user.display_name_or_full_name).to eq('Johnny')
        end
      end

      context 'when display_name is blank' do
        it 'returns the full name' do
          expect(user.display_name_or_full_name).to eq('John Doe')
        end
      end
    end
  end

  describe 'callbacks' do
    it 'sets display_name to full_name if blank' do
      user = create(:user, first_name: 'Jane', last_name: 'Smith', display_name: '')
      expect(user.display_name).to eq('Jane Smith')
    end
  end

  describe 'associations' do
    it { should have_many(:photos).dependent(:destroy) }
    it { should have_one(:family_membership).dependent(:destroy) }
    it { should have_one(:family).through(:family_membership) }
  end

  describe 'family methods' do
    let(:user) { create(:user) }
    let(:family) { create(:family) }

    describe '#has_family?' do
      context 'when user has a family' do
        before do
          create(:family_membership, user: user, family: family)
          user.reload
        end

        it 'returns true' do
          expect(user.has_family?).to be true
        end
      end

      context 'when user has no family' do
        it 'returns false' do
          expect(user.has_family?).to be false
        end
      end
    end

    describe '#can_create_family?' do
      context 'when user has no family' do
        it 'returns true' do
          expect(user.can_create_family?).to be true
        end
      end

      context 'when user has a family' do
        before do
          create(:family_membership, user: user, family: family)
          user.reload
        end

        it 'returns false' do
          expect(user.can_create_family?).to be false
        end
      end
    end

    describe '#family_role' do
      context 'when user has a family' do
        before do
          create(:family_membership, :admin, user: user, family: family)
          user.reload
        end

        it 'returns the role' do
          expect(user.family_role).to eq('admin')
        end
      end

      context 'when user has no family' do
        it 'returns nil' do
          expect(user.family_role).to be_nil
        end
      end
    end

    describe '#family_admin?' do
      context 'when user is admin of their family' do
        before do
          create(:family_membership, :admin, user: user, family: family)
          user.reload
        end

        it 'returns true' do
          expect(user.family_admin?).to be true
        end
      end

      context 'when user is member of their family' do
        before do
          create(:family_membership, user: user, family: family)
          user.reload
        end

        it 'returns false' do
          expect(user.family_admin?).to be false
        end
      end

      context 'when user has no family' do
        it 'returns false' do
          expect(user.family_admin?).to be false
        end
      end
    end

    describe '#admin_of_family?' do
      context 'when user is admin of their family' do
        before do
          create(:family_membership, :admin, user: user, family: family)
          user.reload
        end

        it 'returns true' do
          expect(user.admin_of_family?).to be true
        end
      end

      context 'when user is member of their family' do
        before do
          create(:family_membership, user: user, family: family)
          user.reload
        end

        it 'returns false' do
          expect(user.admin_of_family?).to be false
        end
      end

      context 'when user has no family' do
        it 'returns false' do
          expect(user.admin_of_family?).to be false
        end
      end
    end
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
        expect(user.recent_photos(2).count).to eq(2)
      end
    end
  end
end