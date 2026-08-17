require 'rails_helper'

RSpec.describe "Families", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /families" do
    context "when user has no family" do
      before { sign_in user }

      it "renders index with pending invitations" do
        get families_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user has a family" do
      let!(:family) { create(:family, created_by: user) }
      before { sign_in user.reload }

      it "redirects to the user's family" do
        get families_path
        expect(response).to redirect_to(family_path(family))
      end
    end
  end

  describe "GET /families/:id" do
    let(:family) { create(:family, created_by: user) }

    context "when user is a member" do
      before do
        family
        sign_in user
      end

      it "shows the family" do
        get family_path(family)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not a member" do
      before do
        family
        sign_in other_user
      end

      it "redirects to families index" do
        get family_path(family)
        expect(response).to redirect_to(families_path)
      end
    end
  end

  describe "POST /families" do
    before { sign_in user }

    it "creates a family" do
      expect {
        post families_path, params: { family: { name: "Smiths", description: "Hi" } }
      }.to change(Family, :count).by(1)
      expect(response).to redirect_to(Family.last)
    end

    context "when user already has a family" do
      let!(:existing) { create(:family, created_by: user) }

      it "redirects to the existing family" do
        sign_in user.reload
        post families_path, params: { family: { name: "Other", description: "x" } }
        expect(response).to redirect_to(family_path(existing))
      end
    end
  end

  describe "PATCH /families/:id" do
    let(:family) { create(:family, created_by: user) }

    before do
      family
      sign_in user
    end

    it "updates the family when user is admin" do
      patch family_path(family), params: { family: { name: "Renamed" } }
      expect(family.reload.name).to eq("Renamed")
      expect(response).to redirect_to(family_path(family))
    end
  end

  describe "DELETE /families/:id" do
    let(:family) { create(:family, created_by: user) }

    before do
      family
      sign_in user
    end

    it "deletes the family when user is admin" do
      expect {
        delete family_path(family)
      }.to change(Family, :count).by(-1)
      expect(response).to redirect_to(families_path)
    end
  end

  context "when not signed in" do
    it "redirects index to sign in" do
      get families_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
