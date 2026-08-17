require 'rails_helper'

# track_photo_view used to skip CSRF verification entirely; it no longer does.
# The test environment disables forgery protection globally, so these examples
# turn it on and drive the whole guest flow the way a browser does — which also
# covers the guest password form working under protection.
RSpec.describe "External album view tracking CSRF", type: :request do
  let(:owner) { create(:user) }
  let(:album) do
    create(:album, user: owner, allow_external_access: true, password: "guest-pass")
  end
  let(:photo) { create(:photo, user: owner) }

  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def token_from_body
    response.body[/name="csrf-token" content="([^"]+)"/, 1] ||
      response.body[/name="authenticity_token"[^>]*value="([^"]+)"/, 1]
  end

  def sign_in_as_guest
    get external_album_password_path(album.sharing_token)
    expect(response).to have_http_status(:success)

    post external_album_authenticate_path(album.sharing_token),
         params: { password: "guest-pass", authenticity_token: token_from_body }
    expect(response).to redirect_to(external_album_path(album.sharing_token))
  end

  before { album.add_photo(photo) }

  it "accepts a tracking POST that carries the CSRF token, as the slideshow sends it" do
    sign_in_as_guest

    get external_album_path(album.sharing_token)
    expect(response).to have_http_status(:success)
    token = token_from_body
    expect(token).to be_present, "the guest album page must expose a csrf-token meta tag"

    post track_external_photo_view_path(album.sharing_token),
         params: { photo_id: photo.id }.to_json,
         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }

    expect(response).to have_http_status(:ok)
    expect(AlbumViewEvent.where(event_type: "photo_view", photo_id: photo.id)).to exist
  end

  it "rejects a forged cross-site POST that carries no token" do
    sign_in_as_guest

    expect {
      post track_external_photo_view_path(album.sharing_token),
           params: { photo_id: photo.id }.to_json,
           headers: { "Content-Type" => "application/json" }
    }.not_to change { AlbumViewEvent.where(event_type: "photo_view").count }
  end
end
