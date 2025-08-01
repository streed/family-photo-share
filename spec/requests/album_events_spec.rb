require 'rails_helper'

RSpec.describe "Album Events", type: :request do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }
  let(:other_user) { create(:user) }
  let(:other_album) { create(:album, user: other_user) }

  before do
    sign_in user
  end

  describe "GET /albums/:id/view_events" do
    context "as album owner" do
      before do
        # Create some test events
        create(:album_view_event, :password_entry, album: album, occurred_at: 2.days.ago)
        create(:album_view_event, :password_attempt_failed, album: album, occurred_at: 1.day.ago)
        create(:album_view_event, :photo_view, album: album, occurred_at: 1.hour.ago)
        # Old event that should not appear
        create(:album_view_event, :photo_view, album: album, occurred_at: 10.days.ago)
      end

      it "displays recent events for the album" do
        get view_events_album_path(album)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Guest Activity for")
        expect(response.body).to include(album.name)
        expect(response.body).to include("Password Entry")
        expect(response.body).to include("Failed Attempt")
        expect(response.body).to include("Photo View")
      end

      it "calculates event statistics correctly" do
        get view_events_album_path(album)

        expect(assigns(:events).count).to eq(3) # Should not include the old event
        expect(assigns(:event_counts)['password_entry']).to eq(1)
        expect(assigns(:event_counts)['password_attempt_failed']).to eq(1)
        expect(assigns(:event_counts)['photo_view']).to eq(1)
        expect(assigns(:total_photo_views)).to eq(1)
        expect(assigns(:password_attempts)).to eq(2)
      end

      it "shows unique visitors count" do
        # Clear existing events to get a clean count
        album.album_view_events.destroy_all

        # Create events from different IPs
        create(:album_view_event, album: album, ip_address: '192.168.1.1')
        create(:album_view_event, album: album, ip_address: '192.168.1.2')
        create(:album_view_event, album: album, ip_address: '192.168.1.1') # Duplicate IP

        get view_events_album_path(album)

        expect(assigns(:unique_visitors)).to eq(2) # Should count only unique IP addresses
      end
    end

    context "as non-owner" do
      it "redirects with access denied" do
        get view_events_album_path(other_album)

        expect(response).to redirect_to(other_album)
        expect(flash[:alert]).to include("You can only manage your own albums")
      end
    end

    context "when not signed in" do
      before do
        sign_out user
      end

      it "redirects to sign in page" do
        get view_events_album_path(album)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with no events" do
      it "displays empty state" do
        get view_events_album_path(album)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No Activity Yet")
      end
    end
  end
end
