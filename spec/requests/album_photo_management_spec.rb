require 'rails_helper'

RSpec.describe "Album photo management", type: :request do
  let(:owner) { create(:user) }
  let(:album) { create(:album, user: owner, privacy: "family") }

  before { sign_in owner }

  describe "ordering" do
    it "keeps photos in the order they were added, regardless of EXIF date" do
      recent = create(:photo, user: owner, taken_at: 1.day.ago)
      ancient = create(:photo, user: owner, taken_at: 20.years.ago)

      album.add_photo(recent)
      album.add_photo(ancient)

      expect(album.ordered_photos.map(&:id)).to eq([ recent.id, ancient.id ])
    end

    it "does not reshuffle when the metadata job backfills taken_at later" do
      first = create(:photo, user: owner, taken_at: Time.current)
      second = create(:photo, user: owner, taken_at: nil)

      album.add_photo(first)
      album.add_photo(second)
      before_order = album.ordered_photos.map(&:id)

      # ExtractPhotoMetadataJob discovers an old EXIF date after upload.
      second.update_column(:taken_at, 15.years.ago)

      expect(album.ordered_photos.map(&:id)).to eq(before_order)
    end

    it "can still sort chronologically on request" do
      recent = create(:photo, user: owner, taken_at: 1.day.ago)
      ancient = create(:photo, user: owner, taken_at: 20.years.ago)
      album.add_photo(recent)
      album.add_photo(ancient)

      expect(album.ordered_photos(sort: "date_taken").map(&:id)).to eq([ recent.id, ancient.id ])
      expect(album.ordered_photos(sort: "position").map(&:id)).to eq([ recent.id, ancient.id ])

      album.move_photo(ancient, 1)
      expect(album.ordered_photos(sort: "position").map(&:id)).to eq([ ancient.id, recent.id ])
    end

    it "ignores an unknown sort parameter rather than erroring" do
      album.add_photo(create(:photo, user: owner))

      get album_path(album, sort: "'; DROP TABLE albums; --")

      expect(response).to have_http_status(:success)
    end
  end

  describe "adding a photo over turbo_stream" do
    let!(:photo) { create(:photo, user: owner) }

    it "updates the grid, the count and the picker together" do
      patch add_photo_album_path(album, photo_id: photo.id),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")

      expect(response.body).to include('target="album_photo_grid"')
      expect(response.body).to include('target="album_photo_count"')
      expect(response.body).to include('target="album_add_photos"')
      expect(album.reload.photo_count).to eq(1)
    end

    it "still works as a plain HTML request" do
      patch add_photo_album_path(album, photo_id: photo.id)

      expect(response).to redirect_to(album_path(album))
      expect(album.reload.photos).to include(photo)
    end

    it "will not add another user's photo" do
      stranger_photo = create(:photo, user: create(:user))

      patch add_photo_album_path(album, photo_id: stranger_photo.id)

      expect(response).to redirect_to(album_path(album))
      expect(album.reload.photos).to be_empty
    end
  end

  describe "removing a photo over turbo_stream" do
    let!(:photo) { create(:photo, user: owner) }

    before { album.add_photo(photo) }

    it "returns the photo to the picker and updates the count" do
      delete remove_photo_album_path(album, photo_id: photo.id),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('target="album_photo_count"')
      expect(response.body).to include('target="album_add_photos"')
      # The removed photo is addable again, so it appears in the picker markup.
      expect(response.body).to include("addable_photo_#{photo.id}")
      expect(album.reload.photo_count).to eq(0)
    end
  end

  describe "the add-photo picker" do
    it "offers an upload route instead of a dead end when the library is empty" do
      get album_path(album)

      expect(response.body).to include("You haven't uploaded any photos yet")
      expect(response.body).to include(new_photo_path)
    end
  end
end
