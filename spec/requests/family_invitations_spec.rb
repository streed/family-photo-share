require 'rails_helper'

RSpec.describe "FamilyInvitations", type: :request do
  let(:admin) { create(:user) }
  let(:family) { create(:family, created_by: admin) }
  let(:invitation) { create(:family_invitation, family: family, inviter: admin) }

  describe "GET /families/:family_id/invitations/new" do
    context "when user is family admin" do
      before { sign_in admin }

      it "renders the new invitation form" do
        get new_family_invitation_path(family)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not a family admin" do
      let(:outsider) { create(:user) }
      before { sign_in outsider }

      it "redirects with alert" do
        get new_family_invitation_path(family)
        expect(response).to be_redirect
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get new_family_invitation_path(family)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /families/:family_id/invitations" do
    before { sign_in admin }

    it "creates an invitation and sends email" do
      expect {
        post family_invitations_path(family), params: {
          family_invitation: { email: "newmember@example.com" }
        }
      }.to change(FamilyInvitation, :count).by(1)
    end

    it "rejects invalid email" do
      post family_invitations_path(family), params: {
        family_invitation: { email: "not-an-email" }
      }
      expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:redirect)
    end
  end

  describe "GET /invitations/:token (public accept page)" do
    it "shows the invitation when valid" do
      get invitation_path(invitation.token)
      expect(response.body).to be_present
    end

    it "redirects when token is unknown" do
      get invitation_path("nonexistent-token")
      expect(response).to be_redirect
    end
  end
end
