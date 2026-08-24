require 'rails_helper'

RSpec.describe "Album photo management", type: :request do
  let(:owner) { create(:user) }
  let(:album) { create(:album, user: owner, privacy: "family") }

  before { sign_in owner }

  describe "ordering" do
    it "shows the most recently added photo first, regardless of EXIF date" do
      recent = create(:photo, user: owner, taken_at: 1.day.ago)
      ancient = create(:photo, user: owner, taken_at: 20.years.ago)

      album.add_photo(recent)
      album.add_photo(ancient)

      # ancient was added last, so it leads — the album opens on what you just put in it.
      expect(album.ordered_photos.map(&:id)).to eq([ ancient.id, recent.id ])
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

      # Both orderings are newest-first; they differ in what "newest" means —
      # when the photo was taken, versus when it was added to the album.
      expect(album.ordered_photos(sort: "date_taken").map(&:id)).to eq([ recent.id, ancient.id ])
      expect(album.ordered_photos(sort: "position").map(&:id)).to eq([ ancient.id, recent.id ])

      album.move_photo(ancient, 1)
      expect(album.ordered_photos(sort: "position").map(&:id)).to eq([ recent.id, ancient.id ])
    end

    it "ignores an unknown sort parameter rather than erroring" do
      album.add_photo(create(:photo, user: owner))

      get album_path(album, sort: "'; DROP TABLE albums; --")

      expect(response).to have_http_status(:success)
    end
  end

  describe "paging the grid" do
    # 30 photos over a 24-per-page grid: enough for a second page and no more.
    let!(:photos) { Array.new(30) { |i| create(:photo, user: owner, title: "photo-#{i}") } }

    before { photos.each { |photo| album.add_photo(photo) } }

    it "shows a screenful of the most recent additions, newest first" do
      get album_path(album)

      rendered = response.body.scan(/id="photo_(\d+)"/).flatten.map(&:to_i)

      expect(rendered.size).to eq(AlbumsController::PHOTOS_PER_PAGE)
      expect(rendered.first).to eq(photos.last.id)
      expect(rendered).to eq(rendered.sort.reverse)
      expect(response.body).to include("page 1 of 2")
    end

    it "puts the oldest additions on the last page" do
      get album_path(album, page: 2)

      rendered = response.body.scan(/id="photo_(\d+)"/).flatten.map(&:to_i)

      expect(rendered.size).to eq(6)
      expect(rendered.last).to eq(photos.first.id)
    end

    it "keeps the whole album reachable across the pages" do
      first_page = response_photo_ids(album_path(album))
      second_page = response_photo_ids(album_path(album, page: 2))

      expect((first_page + second_page).uniq.size).to eq(30)
    end

    it "clamps a page past the end rather than showing an empty grid" do
      get album_path(album, page: 99)

      expect(response).to have_http_status(:ok)
      expect(response.body.scan(/id="photo_(\d+)"/)).not_to be_empty
    end

    it "ignores a nonsense page the same way" do
      get album_path(album, page: "'; DROP TABLE albums; --")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("page 1 of 2")
    end

    def response_photo_ids(path)
      get path
      response.body.scan(/id="photo_(\d+)"/).flatten.map(&:to_i)
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

      expect(response.body).to include("You haven't uploaded any photos")
      expect(response.body).to include(new_photo_path)
    end
  end
end
