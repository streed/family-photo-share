require 'rails_helper'

RSpec.describe FamilyInvitation, type: :model do
  describe 'associations' do
    it { should belong_to(:family) }
    it { should belong_to(:inviter).class_name('User') }
  end

  describe 'validations' do
    subject { build(:family_invitation) }

    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[pending accepted declined expired]) }
    
    it 'ensures token is generated automatically' do
      invitation = build(:family_invitation, token: nil)
      invitation.valid?
      expect(invitation.token).to be_present
    end
    
    it 'validates email format' do
      invitation = build(:family_invitation, email: 'invalid-email')
      expect(invitation).not_to be_valid
      expect(invitation.errors[:email]).to be_present
    end
  end

  describe 'callbacks' do
    it 'generates token before validation on create' do
      invitation = build(:family_invitation, token: nil)
      invitation.valid?
      expect(invitation.token).to be_present
    end

    it 'sets expiration before validation on create' do
      invitation = build(:family_invitation, expires_at: nil)
      invitation.valid?
      expect(invitation.expires_at).to be_present
    end
  end

  describe 'scopes' do
    let!(:pending_invitation) { create(:family_invitation) }
    let!(:accepted_invitation) { create(:family_invitation, :accepted) }
    let!(:declined_invitation) { create(:family_invitation, :declined) }
    let!(:expired_invitation) { create(:family_invitation, :expired) }

    describe '.pending' do
      it 'returns only pending invitations' do
        expect(FamilyInvitation.pending).to include(pending_invitation)
        expect(FamilyInvitation.pending).not_to include(accepted_invitation)
      end
    end

    describe '.accepted' do
      it 'returns only accepted invitations' do
        expect(FamilyInvitation.accepted).to include(accepted_invitation)
        expect(FamilyInvitation.accepted).not_to include(pending_invitation)
      end
    end

    describe '.active' do
      it 'returns pending non-expired invitations' do
        expect(FamilyInvitation.active).to include(pending_invitation)
        expect(FamilyInvitation.active).not_to include(expired_invitation)
      end
    end
  end

  describe 'instance methods' do
    let(:invitation) { create(:family_invitation) }
    let(:user) { create(:user, email: invitation.email) }

    describe '#pending?' do
      it 'returns true for pending status' do
        expect(invitation.pending?).to be true
      end
    end

    describe '#expired?' do
      it 'returns false for future expiration' do
        invitation.update!(expires_at: 1.day.from_now)
        expect(invitation.expired?).to be false
      end

      it 'returns true for past expiration' do
        invitation.update!(expires_at: 1.day.ago)
        expect(invitation.expired?).to be true
      end
    end

    describe '#accept!' do
      it 'changes status to accepted' do
        invitation.accept!(user)
        expect(invitation.reload.status).to eq('accepted')
      end

      it 'creates family membership for user' do
        expect {
          invitation.accept!(user)
        }.to change(invitation.family.family_memberships, :count).by(1)
      end

      it 'returns false if expired' do
        invitation.update!(expires_at: 1.day.ago)
        expect(invitation.accept!(user)).to be false
      end
    end

    describe '#decline!' do
      it 'changes status to declined' do
        invitation.decline!
        expect(invitation.reload.status).to eq('declined')
      end
    end

    describe '#invited_user' do
      it 'returns user with matching email' do
        invitation_with_user_email = create(:family_invitation, email: user.email)
        expect(invitation_with_user_email.invited_user).to eq(user)
      end

      it 'returns nil if no user found' do
        invitation.update!(email: 'nonexistent@example.com')
        expect(invitation.invited_user).to be_nil
      end
    end
  end
end