require 'rails_helper'

RSpec.describe FamilyMembership, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:family) }
  end

  describe 'validations' do
    subject { build(:family_membership) }

    it { should validate_presence_of(:role) }
    it { should validate_inclusion_of(:role).in_array(%w[admin member]) }
    it { should validate_uniqueness_of(:user_id).with_message('can only belong to one family') }

    describe 'user can only belong to one family' do
      let(:user) { create(:user) }
      let(:family1) { create(:family) }
      let(:family2) { create(:family) }

      it 'allows creating the first family membership' do
        membership = build(:family_membership, user: user, family: family1)
        expect(membership).to be_valid
      end

      it 'prevents creating a second family membership for the same user' do
        create(:family_membership, user: user, family: family1)
        membership = build(:family_membership, user: user, family: family2)
        expect(membership).not_to be_valid
        expect(membership.errors[:user_id]).to include('can only belong to one family')
      end
    end
  end

  describe 'scopes' do
    let!(:admin_membership) { create(:family_membership, :admin) }
    let!(:member_membership) { create(:family_membership) }

    describe '.admins' do
      it 'returns only admin memberships' do
        expect(FamilyMembership.admins).to include(admin_membership)
        expect(FamilyMembership.admins).not_to include(member_membership)
      end
    end

    describe '.members' do
      it 'returns only member memberships' do
        expect(FamilyMembership.members).to include(member_membership)
        expect(FamilyMembership.members).not_to include(admin_membership)
      end
    end
  end

  describe 'instance methods' do
    let(:admin_membership) { create(:family_membership, :admin) }
    let(:member_membership) { create(:family_membership) }

    describe '#admin?' do
      it 'returns true for admin role' do
        expect(admin_membership.admin?).to be true
      end

      it 'returns false for member role' do
        expect(member_membership.admin?).to be false
      end
    end

    describe '#member?' do
      it 'returns true for member role' do
        expect(member_membership.member?).to be true
      end

      it 'returns false for admin role' do
        expect(admin_membership.member?).to be false
      end
    end

    describe '#can_invite?' do
      it 'returns true for admin' do
        expect(admin_membership.can_invite?).to be true
      end

      it 'returns false for member' do
        expect(member_membership.can_invite?).to be false
      end
    end

    describe '#can_manage_members?' do
      it 'returns true for admin' do
        expect(admin_membership.can_manage_members?).to be true
      end

      it 'returns false for member' do
        expect(member_membership.can_manage_members?).to be false
      end
    end
  end
end
