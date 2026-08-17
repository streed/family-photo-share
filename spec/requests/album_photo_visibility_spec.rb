require 'rails_helper'

# Covers the reported bug: "photos added to an album don't always show up in the
# user's UI, so it's not clear if they are properly shared."
RSpec.describe "Album photo visibility", type: :request do
  let(:family) { create(:family) }
  let(:owner) { create(:user) }
  let(:relative) { create(:user) }
  let(:stranger) { create(:user) }

  def attach_image(photo)
    photo.image.attach(
      io: Rails.root.join("spec/fixtures/files/test_image.jpg").open,
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )
    photo
  end

  describe "a family member viewing a shared album" do
    before do
      create(:family_membership, user: owner, family: family)
      create(:family_membership, user: relative, family: family)
      owner.reload
      relative.reload
    end

    let!(:album) { create(:album, user: owner, privacy: "family") }
    let!(:photo) { attach_image(create(:photo, user: owner)) }

    before { album.add_photo(photo) }

    it "lets the family member load the album page" do
      sign_in relative
      get album_path(album)

      expect(response).to have_http_status(:success)
    end

    it "serves the photo image rather than erroring or 404ing" do
      sign_in relative
      get photo.short_thumbnail_url

      expect(response).to have_http_status(:success)
      expect(response.content_type).to start_with("image/")
    end

    it "lists the album under albums shared with them" do
      sign_in relative
      get albums_path

      expect(response.body).to include(ERB::Util.html_escape(album.name))
      expect(response.body).to include("Shared with you")
    end
  end

  describe "images for photos whose variants have not been processed yet" do
    let!(:album) { create(:album, user: owner, privacy: "private") }
    let!(:photo) { attach_image(create(:photo, user: owner)) }

    before { album.add_photo(photo) }

    it "still serves every variant size" do
      sign_in owner

      expect(photo.processing_completed_at).to be_nil

      %i[thumbnail small medium large xl].each do |size|
        get ShortUrl.for_photo_variant(photo, size).short_path

        expect(response).to have_http_status(:success), "expected #{size} to render"
        expect(response.content_type).to start_with("image/")
      end
    end
  end

  describe "access control" do
    let!(:private_album) { create(:album, user: owner, privacy: "private") }
    let!(:photo) { attach_image(create(:photo, user: owner)) }

    before { private_album.add_photo(photo) }

    it "does not let a stranger view someone else's photo" do
      sign_in stranger
      get photo_path(photo)

      expect(response).to redirect_to(photos_path)
    end

    it "does not serve a stranger the photo bytes" do
      sign_in stranger
      get photo.short_thumbnail_url

      expect(response).to have_http_status(:forbidden)
    end

    it "does not let a family member reach photos in the owner's private album" do
      create(:family_membership, user: owner, family: family)
      create(:family_membership, user: relative, family: family)
      owner.reload
      relative.reload

      sign_in relative
      get photo.short_thumbnail_url

      expect(response).to have_http_status(:forbidden)
    end

    it "does not let a user enumerate a stranger's library" do
      sign_in stranger
      get photos_path(user_id: owner.id)

      expect(response).to redirect_to(photos_path)
    end

    it "never marks authorized image responses as publicly cacheable" do
      sign_in owner
      get photo.short_thumbnail_url

      expect(response.headers["Cache-Control"]).to include("private")
      expect(response.headers["Cache-Control"]).not_to include("public")
    end
  end

  describe "the add-photo picker" do
    let!(:album) { create(:album, user: owner, privacy: "family") }

    it "reports how many photos are available beyond the 20 it shows" do
      25.times { create(:photo, user: owner) }

      sign_in owner
      get album_path(album)

      expect(response.body).to include("Showing 20 of 25 photos not yet in this album")
    end
  end
end
