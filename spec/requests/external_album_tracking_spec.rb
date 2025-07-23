require 'rails_helper'

RSpec.describe "External Album Tracking", type: :request do
  let(:user) { create(:user) }
  let(:album) do
    album = create(:album, user: user)
    album.update!(allow_external_access: true, password: 'secretpass')
    album
  end
  let(:photo) { create(:photo, user: user) }
  
  before do
    album.add_photo(photo)
  end
  
  describe "POST /shared/albums/:token/authenticate" do
    context "with correct password" do
      it "tracks password entry event" do
        expect {
          post external_album_authenticate_path(album.sharing_token), 
               params: { password: 'secretpass' },
               headers: { 'HTTP_USER_AGENT' => 'RSpec Test Browser' }
        }.to change { AlbumViewEvent.count }.by(1)
        
        event = AlbumViewEvent.last
        expect(event.album).to eq(album)
        expect(event.event_type).to eq('password_entry')
        expect(event.photo).to be_nil
        expect(event.ip_address).to be_present
        expect(event.user_agent).to eq('RSpec Test Browser')
        expect(event.session_id).to be_present
      end
      
      it "redirects to album view" do
        post external_album_authenticate_path(album.sharing_token), params: { password: 'secretpass' }
        expect(response).to redirect_to(external_album_path(album.sharing_token))
      end
    end
    
    context "with incorrect password" do
      it "tracks failed password attempt" do
        expect {
          post external_album_authenticate_path(album.sharing_token), 
               params: { password: 'wrongpass' },
               headers: { 'HTTP_USER_AGENT' => 'RSpec Test Browser' }
        }.to change { AlbumViewEvent.count }.by(1)
        
        event = AlbumViewEvent.last
        expect(event.album).to eq(album)
        expect(event.event_type).to eq('password_attempt_failed')
        expect(event.photo).to be_nil
        expect(event.ip_address).to be_present
        expect(event.user_agent).to eq('RSpec Test Browser')
      end
      
      it "renders password form with error" do
        post external_album_authenticate_path(album.sharing_token), params: { password: 'wrongpass' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Incorrect password')
      end
    end
  end
  
  describe "POST /shared/albums/:token/track_photo_view" do
    context "with valid session" do
      before do
        # Authenticate first to get a valid session
        post external_album_authenticate_path(album.sharing_token), params: { password: 'secretpass' }
      end
      
      it "tracks photo view event" do
        expect {
          post track_external_photo_view_path(album.sharing_token), 
               params: { photo_id: photo.id }.to_json,
               headers: { 'Content-Type': 'application/json', 'HTTP_USER_AGENT' => 'RSpec Test Browser' }
        }.to change { AlbumViewEvent.count }.by(1)
        
        event = AlbumViewEvent.last
        expect(event.album).to eq(album)
        expect(event.photo).to eq(photo)
        expect(event.event_type).to eq('photo_view')
        expect(event.ip_address).to be_present
        expect(event.user_agent).to be_present
        expect(event.session_id).to be_present
      end
      
      it "returns success status" do
        post track_external_photo_view_path(album.sharing_token), 
             params: { photo_id: photo.id }.to_json,
             headers: { 'Content-Type': 'application/json' }
        expect(response).to have_http_status(:ok)
      end
      
      it "returns not found for non-existent photo" do
        post track_external_photo_view_path(album.sharing_token), 
             params: { photo_id: 99999 }.to_json,
             headers: { 'Content-Type': 'application/json' }
        expect(response).to have_http_status(:not_found)
      end
    end
    
    context "without valid session" do
      it "redirects to password form" do
        post track_external_photo_view_path(album.sharing_token), 
             params: { photo_id: photo.id }.to_json,
             headers: { 'Content-Type': 'application/json' }
        expect(response).to redirect_to(external_album_password_path(album.sharing_token))
      end
      
      it "does not track photo view event" do
        expect {
          post track_external_photo_view_path(album.sharing_token), 
               params: { photo_id: photo.id }.to_json,
               headers: { 'Content-Type': 'application/json' }
        }.not_to change { AlbumViewEvent.count }
      end
    end
  end
  
  describe "event cleanup" do
    it "removes events older than 7 days" do
      # Create events with different ages
      create(:album_view_event, album: album, occurred_at: 3.days.ago)
      create(:album_view_event, album: album, occurred_at: 8.days.ago)
      create(:album_view_event, album: album, occurred_at: 15.days.ago)
      
      expect(AlbumViewEvent.count).to eq(3)
      
      # Run cleanup job
      CleanupAlbumViewEventsJob.new.perform
      
      # Only recent event should remain
      expect(AlbumViewEvent.count).to eq(1)
      expect(AlbumViewEvent.recent.count).to eq(1)
    end
  end
end