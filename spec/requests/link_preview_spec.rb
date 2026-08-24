require 'rails_helper'

# What a link preview is allowed to show.
#
# The app had no Open Graph tags at all, which is not neutral: with no og:image,
# crawlers fall back to scraping the page for the largest <img>, so pasting a
# shared-album link into a chat republished one of the family's photos as the
# preview thumbnail. These pin the preview to a fixed app icon.
RSpec.describe "Link previews", type: :request do
  let(:owner) { create(:user) }

  # Every meta tag on the page, so a photo URL can't hide in one we didn't think
  # to name.
  def meta_tags
    response.body.scan(/<meta [^>]*>/i)
  end

  def preview_tags
    meta_tags.select { |tag| tag.match?(/og:|twitter:/i) }
  end

  describe "a shared album with no password — what an unauthenticated crawler sees" do
    let(:album) { create(:album, user: owner, allow_external_access: true) }
    let!(:photo) { create(:photo, user: owner) }

    before do
      album.add_photo(photo)
      get external_album_path(album.sharing_token)
    end

    it "serves the album, photos and all" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/s/")
    end

    it "points the preview at the app icon" do
      expect(preview_tags).to include(a_string_matching(%r{og:image.*/icon\.png}))
      expect(preview_tags).to include(a_string_matching(/twitter:card.*summary"/))
    end

    it "puts no photo of any kind in a preview tag" do
      expect(preview_tags).to be_present

      preview_tags.each do |tag|
        expect(tag).not_to match(%r{/s/}),                     "photo short URL in #{tag}"
        expect(tag).not_to match(%r{rails/active_storage}),    "Active Storage URL in #{tag}"
        expect(tag).not_to match(/\.jpe?g|\.gif|\.webp/i),     "photo file in #{tag}"
      end
    end

    it "names neither the album nor its owner in the preview" do
      preview_tags.each do |tag|
        expect(tag).not_to include(album.name)
        expect(tag).not_to include(owner.display_name_or_full_name)
      end
    end
  end

  describe "the password gate" do
    let(:album) { create(:album, user: owner, allow_external_access: true, password: "letmein") }

    it "shows the same neutral preview" do
      get external_album_path(album.sharing_token)
      follow_redirect!

      expect(preview_tags).to include(a_string_matching(%r{og:image.*/icon\.png}))
      preview_tags.each { |tag| expect(tag).not_to include(album.name) }
    end
  end

  describe "the signed-in side of the app" do
    it "also previews as the icon rather than whatever image is on the page" do
      sign_in owner
      album = create(:album, user: owner)
      album.add_photo(create(:photo, user: owner))

      get album_path(album)

      expect(preview_tags).to include(a_string_matching(%r{og:image.*/icon\.png}))
      preview_tags.each { |tag| expect(tag).not_to match(%r{/s/}) }
    end
  end
end
