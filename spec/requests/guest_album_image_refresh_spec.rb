require 'rails_helper'

RSpec.describe "Guest album image access over time", type: :request do
  let(:owner) { create(:user) }
  let(:album) { create(:album, user: owner, allow_external_access: true, password: "secret123") }
  let!(:photo) { create(:photo, user: owner) }

  before { album.photos << photo }

  def thumbnail_path
    URI.parse(photo.short_thumbnail_url).path
  end

  def sign_in_as_guest
    post external_album_authenticate_path(album.sharing_token), params: { password: "secret123" }
    follow_redirect!
  end

  it "serves the images right after the guest signs in" do
    sign_in_as_guest

    get thumbnail_path
    expect(response).to have_http_status(:ok)
  end

  it "still serves the images after the guest refreshes the album page" do
    sign_in_as_guest

    get external_album_path(album.sharing_token)
    expect(response).to have_http_status(:ok)

    get thumbnail_path
    expect(response).to have_http_status(:ok)
  end

  # The regression: the signed cookie that authorizes photo requests was issued
  # once at sign-in and never re-issued, while the database session went on
  # being extended. Access died at a fixed wall-clock time regardless of use.
  it "keeps serving images while the guest keeps browsing the album" do
    sign_in_as_guest

    # Well past the original cookie's expiry, but the guest has been active.
    travel_to(25.minutes.from_now) do
      get external_album_path(album.sharing_token)
      expect(response).to have_http_status(:ok)
    end

    travel_to(45.minutes.from_now) do
      get external_album_path(album.sharing_token)
      expect(response).to have_http_status(:ok)

      get thumbnail_path
      expect(response).to have_http_status(:ok)
    end
  end

  # A slideshow makes no page requests at all, only image ones.
  it "keeps serving images to a guest who only ever requests photos" do
    sign_in_as_guest

    travel_to(25.minutes.from_now) do
      get thumbnail_path
      expect(response).to have_http_status(:ok)
    end

    travel_to(45.minutes.from_now) do
      get thumbnail_path
      expect(response).to have_http_status(:ok)
    end
  end

  it "stops serving images once the guest has genuinely gone idle" do
    sign_in_as_guest

    travel_to(31.minutes.from_now) do
      get thumbnail_path
      expect(response).not_to have_http_status(:ok)
    end
  end

  it "does not write to the session on every tile of a freshly loaded grid" do
    sign_in_as_guest
    session_record = album.album_access_sessions.order(:created_at).last

    expect {
      3.times { get thumbnail_path }
    }.not_to change { session_record.reload.expires_at }
  end
end
