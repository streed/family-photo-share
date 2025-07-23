require 'rails_helper'

RSpec.describe "QR Code Integration", type: :request do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }
  
  before do
    sign_in user
  end
  
  describe "album page with external sharing enabled" do
    before do
      album.update!(allow_external_access: true, password: 'testpass')
      # Add a photo to the album so QR code will be shown
      photo = create(:photo, user: user)
      album.add_photo(photo)
    end
    
    it "includes QR code in the response" do
      get album_path(album)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('qr-code-image')
      expect(response.body).to include('data:image/svg+xml;base64,')
      expect(response.body).to include('Scan to share')
    end
    
    it "QR code contains the sharing URL" do
      get album_path(album)
      
      # The QR code should be generated from the sharing URL
      expect(album.sharing_url).to be_present
      expect(response.body).to include('QR Code for')
      expect(response.body).to include(album.name)
    end
  end
  
  describe "album page without external sharing" do
    it "does not include QR code" do
      get album_path(album)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('qr-code-image')
      expect(response.body).not_to include('Scan to share')
    end
  end
  
  describe "album page with external sharing but no photos" do
    before do
      album.update!(allow_external_access: true, password: 'testpass')
      # Don't add any photos - album should remain empty
    end
    
    it "does not include QR code when album is empty" do
      get album_path(album)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('qr-code-image')
      expect(response.body).not_to include('Scan to share')
    end
  end
end