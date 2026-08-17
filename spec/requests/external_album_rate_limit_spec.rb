require 'rails_helper'

RSpec.describe "External album password rate limiting", type: :request do
  let(:owner) { create(:user) }
  let(:album) do
    create(:album, user: owner, allow_external_access: true, password: "correct-horse")
  end

  def attempt(password)
    post external_album_authenticate_path(album.sharing_token), params: { password: password }
  end

  it "counts down the remaining attempts" do
    attempt("nope")
    expect(response.body).to include("You have 4 attempts remaining")
  end

  it "blocks after the maximum number of attempts" do
    ExternalAlbumsController::MAX_PASSWORD_ATTEMPTS.times { attempt("nope") }
    attempt("nope")

    expect(response).to have_http_status(:too_many_requests)
    expect(response.body).to include("Too many incorrect password attempts")
  end

  # The lockout used to advertise 15 minutes while the cache entry lived for an
  # hour, so a guest came back on time and was still blocked.
  it "advertises a wait that matches how long the block actually lasts" do
    ExternalAlbumsController::MAX_PASSWORD_ATTEMPTS.times { attempt("nope") }
    attempt("nope")

    advertised = response.body[/try again in (\d+) minute/, 1].to_i
    expect(advertised).to be > 0
    expect(advertised).to be <= ExternalAlbumsController::LOCKOUT_DURATION.in_minutes.ceil

    travel_to(ExternalAlbumsController::LOCKOUT_DURATION.from_now + 1.minute) do
      attempt("correct-horse")
      expect(response).to redirect_to(external_album_path(album.sharing_token))
    end
  end

  it "renders the password form rather than a raw JSON blob when blocked" do
    ExternalAlbumsController::MAX_PASSWORD_ATTEMPTS.times { attempt("nope") }
    attempt("nope")

    expect(response.body).not_to start_with("{")
    expect(response.body).to include("<form")
  end

  it "clears the counter after a successful sign-in" do
    2.times { attempt("nope") }
    attempt("correct-horse")

    expect(response).to redirect_to(external_album_path(album.sharing_token))

    attempt("nope")
    expect(response.body).to include("You have 4 attempts remaining")
  end
end
