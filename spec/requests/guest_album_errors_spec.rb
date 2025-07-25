require 'rails_helper'

RSpec.describe "Guest Album Error Handling", type: :request do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user, allow_external_access: true, password: "secret123") }
  
  describe "Password authentication errors" do
    context "with incorrect password" do
      it "shows an error message for first attempt" do
        post external_album_authenticate_path(album.sharing_token), params: {
          password: "wrongpassword"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Incorrect password")
        expect(response.body).to include("You have 4 attempts remaining")
      end
      
      it "shows warning message on last attempt" do
        # Simulate 4 failed attempts
        4.times do
          post external_album_authenticate_path(album.sharing_token), params: {
            password: "wrongpassword"
          }
        end
        
        expect(response.body).to include("You have 1 more attempt before access is temporarily blocked")
      end
      
      it "blocks access after maximum failed attempts" do
        # Simulate 5 failed attempts
        5.times do
          post external_album_authenticate_path(album.sharing_token), params: {
            password: "wrongpassword"
          }
        end
        
        # Try one more time
        post external_album_authenticate_path(album.sharing_token), params: {
          password: "wrongpassword"
        }
        
        expect(response.body).to include("Too many incorrect password attempts")
        expect(response.body).to include("temporarily blocked")
      end
    end
    
    context "with correct password" do
      it "shows success message and grants access" do
        post external_album_authenticate_path(album.sharing_token), params: {
          password: "secret123"
        }
        
        expect(response).to redirect_to(external_album_path(album.sharing_token))
        follow_redirect!
        expect(response.body).to include("Welcome! You now have access to view this album")
        expect(response.body).to include("Your session will expire in 10 minutes")
      end
    end
  end
  
  describe "Album access errors" do
    context "when album doesn't exist" do
      it "returns 404 for invalid token" do
        get external_album_path("invalid_token")
        expect(response).to have_http_status(:not_found)
      end
    end
    
    context "when external access is disabled" do
      let(:private_album) { create(:album, user: user, allow_external_access: false) }
      
      it "returns 404 for disabled external access" do
        get external_album_path(private_album.sharing_token)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
  
  describe "Session expiration" do
    let(:expired_session) { create(:album_access_session, album: album, expires_at: 1.hour.ago) }
    
    it "redirects to password form when session expires" do
      # Set expired session cookie
      request.cookies.signed[:album_access] = {
        'token' => expired_session.session_token,
        'album_id' => album.id
      }
      
      get external_album_path(album.sharing_token)
      expect(response).to redirect_to(external_album_password_path(album.sharing_token))
    end
  end
end

RSpec.describe "Guest Session Management Errors", type: :request do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user, allow_external_access: true) }
  let(:guest_session) { create(:album_access_session, album: album) }
  
  before { sign_in user }
  
  describe "Revoking individual session" do
    it "shows success message when revoking active session" do
      delete revoke_guest_session_album_path(album), params: { session_token: guest_session.session_token }
      
      expect(response).to redirect_to(guest_sessions_album_path(album))
      follow_redirect!
      expect(response.body).to include("Guest session revoked successfully")
      expect(response.body).to include("guest user has been logged out")
    end
    
    it "shows error message for non-existent session" do
      delete revoke_guest_session_album_path(album), params: { session_token: "invalid_token" }
      
      expect(response).to redirect_to(guest_sessions_album_path(album))
      follow_redirect!
      expect(response.body).to include("Session not found or already removed")
    end
  end
  
  describe "Revoking all sessions" do
    it "shows success message when revoking multiple sessions" do
      create_list(:album_access_session, 3, album: album)
      
      patch revoke_all_guest_sessions_album_path(album)
      
      expect(response).to redirect_to(guest_sessions_album_path(album))
      follow_redirect!
      expect(response.body).to include("3 active guest sessions revoked")
      expect(response.body).to include("All guest users have been logged out")
    end
    
    it "shows error message when no active sessions exist" do
      patch revoke_all_guest_sessions_album_path(album)
      
      expect(response).to redirect_to(guest_sessions_album_path(album))
      follow_redirect!
      expect(response.body).to include("No active guest sessions to revoke")
    end
  end
end