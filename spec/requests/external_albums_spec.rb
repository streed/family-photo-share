require 'rails_helper'

RSpec.describe "ExternalAlbums", type: :request do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }

  describe "GET /shared/albums/:token" do
    context "when album has external access enabled with password" do
      before do
        album.update!(
          allow_external_access: true,
          password: 'test123',
          sharing_token: SecureRandom.urlsafe_base64(16)
        )
      end

      it "redirects to password form when no session exists" do
        get external_album_path(album.sharing_token)

        expect(response).to redirect_to(external_album_password_path(album.sharing_token))
      end

      it "shows album after successful authentication" do
        # First authenticate with password
        post external_album_authenticate_path(album.sharing_token), params: { password: 'test123' }
        expect(response).to redirect_to(external_album_path(album.sharing_token))

        # Follow redirect and verify we can now access the album
        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(response.body).to include(album.name)
      end

      it "rejects incorrect password" do
        post external_album_authenticate_path(album.sharing_token), params: { password: 'wrong' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Incorrect password')
      end

      it "maintains access with valid session cookie" do
        # Authenticate first
        post external_album_authenticate_path(album.sharing_token), params: { password: 'test123' }

        # Access album directly with session cookie
        get external_album_path(album.sharing_token)
        expect(response).to have_http_status(:success)
      end
    end

    context "when album has external access disabled" do
      before do
        album.update!(
          allow_external_access: false,
          sharing_token: SecureRandom.urlsafe_base64(16)
        )
      end

      it "returns 404" do
        get external_album_path(album.sharing_token)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when album doesn't exist" do
      it "returns 404" do
        get external_album_path('invalid-token')
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "rate limiting" do
    before do
      album.update!(
        allow_external_access: true,
        password: 'test123',
        sharing_token: SecureRandom.urlsafe_base64(16)
      )
    end

    it "limits password attempts" do
      # Make 5 failed attempts
      5.times do
        post external_album_authenticate_path(album.sharing_token), params: { password: 'wrong' }
      end

      # 6th attempt should be rate limited
      post external_album_authenticate_path(album.sharing_token), params: { password: 'test123' }
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
