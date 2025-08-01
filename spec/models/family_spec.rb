require 'rails_helper'

RSpec.describe Family, type: :model do
  describe 'associations' do
    it { should belong_to(:created_by).class_name('User') }
    it { should have_many(:family_memberships).dependent(:destroy) }
    it { should have_many(:members).through(:family_memberships).source(:user) }
    it { should have_many(:family_invitations).dependent(:destroy) }
    it { should have_many(:shared_photos).through(:members).source(:photos) }
  end

  describe 'validations' do
    subject { build(:family) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(500) }
  end

  describe 'callbacks' do
    it 'adds creator as admin after creation' do
      user = create(:user)
      family = create(:family, created_by: user)

      membership = family.family_memberships.find_by(user: user)
      expect(membership).to be_present
      expect(membership.role).to eq('admin')
    end
  end

  describe 'instance methods' do
    let(:family) { create(:family) }
    let(:admin_user) { family.created_by }
    let(:member_user) { create(:user) }

    before do
      create(:family_membership, family: family, user: member_user, role: 'member')
    end

    describe '#admin?' do
      it 'returns true for admin users' do
        expect(family.admin?(admin_user)).to be true
      end

      it 'returns false for non-admin users' do
        expect(family.admin?(member_user)).to be false
      end
    end

    describe '#member?' do
      it 'returns true for family members' do
        expect(family.member?(admin_user)).to be true
        expect(family.member?(member_user)).to be true
      end

      it 'returns false for non-members' do
        non_member = create(:user)
        expect(family.member?(non_member)).to be false
      end
    end

    describe '#member_count' do
      it 'returns the correct number of members' do
        expect(family.member_count).to eq(2) # admin + member
      end
    end
  end
end
