require 'rails_helper'

RSpec.describe "ShortUrls", type: :request do
  let(:owner) { create(:user) }
  let(:photo) { create(:photo, user: owner) }
  let(:short_url) { ShortUrl.for_photo_variant(photo, :original) }

  describe "GET /s/:token" do
    context "when not signed in and the photo is not externally shared" do
      it "redirects to sign in" do
        get short_url_path(short_url.token)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as the owner" do
      before { sign_in owner }

      it "serves the image" do
        get short_url_path(short_url.token)
        expect(response).to have_http_status(:success)
        expect(response.content_type).to start_with("image/")
      end
    end

    context "when signed in as a non-owner with no family overlap" do
      let(:other_user) { create(:user) }

      before { sign_in other_user }

      it "returns 403" do
        get short_url_path(short_url.token)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the token is unknown" do
      it "returns 404" do
        get short_url_path("does-not-exist")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the short URL has expired" do
      it "returns 410 gone" do
        short_url.update_column(:expires_at, 1.day.ago)
        get short_url_path(short_url.token)
        expect(response).to have_http_status(:gone)
      end
    end
  end
end
