require 'rails_helper'

RSpec.describe "FamilyInvitations", type: :request do
  describe "GET /new" do
    it "returns http success" do
      get "/family_invitations/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/family_invitations/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/family_invitations/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
