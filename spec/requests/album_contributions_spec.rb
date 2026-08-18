require 'rails_helper'

# Collaborative albums. Until now Album#editable_by? was `self.user == user`, so
# a "family" album was something the family could look at and nobody but its
# creator could ever add to. These specs pin down the new middle ground: a
# contributor adds their own photos and withdraws their own photos, and nothing
# else about the album moves.
RSpec.describe "Collaborative albums", type: :request do
  let(:family) { create(:family, created_by: owner) }
  let(:owner) { create(:user) }
  let(:relative) { create(:user) }
  let(:outsider) { create(:user) }

  let(:album) { create(:album, user: owner, privacy: "family", allow_contributions: true) }

  # The family factory makes its creator an admin member, so owner only needs a
  # relative added alongside them.
  before do
    create(:family_membership, user: relative, family: family)
    [ owner, relative ].each(&:reload)
  end

  describe "a family member adding to an open album" do
    let!(:photo) { create(:photo, user: relative) }

    before { sign_in relative }

    it "adds their own photo" do
      patch add_photo_album_path(album, photo_id: photo.id)

      expect(response).to redirect_to(album_path(album))
      expect(album.reload.photos).to include(photo)
    end

    it "sees the album on the index, marked as one the family can add to" do
      album # created before the request, not lazily by the expectation below
      get albums_path

      expect(response.body).to include(album.name)
      expect(response.body).to include("Family can add")
    end

    it "sees the picker on the album page" do
      get album_path(album)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Add photos to this album")
      expect(response.body).to include("opened this album up to the family")
    end

    it "still cannot add somebody else's photo" do
      stranger_photo = create(:photo, user: outsider)

      patch add_photo_album_path(album, photo_id: stranger_photo.id)

      expect(album.reload.photos).to be_empty
    end

    it "can take their own photo back out" do
      album.add_photo(photo)

      delete remove_photo_album_path(album, photo_id: photo.id)

      expect(album.reload.photos).to be_empty
    end

    it "cannot remove a photo somebody else put in" do
      owners_photo = create(:photo, user: owner)
      album.add_photo(owners_photo)

      delete remove_photo_album_path(album, photo_id: owners_photo.id)

      expect(response).to redirect_to(album_path(album))
      expect(flash[:alert]).to match(/only remove photos you added/i)
      expect(album.reload.photos).to include(owners_photo)
    end

    it "gets no cover-photo control" do
      album.add_photo(photo)

      patch set_cover_album_path(album, photo_id: photo.id)

      expect(response).to redirect_to(album_path(album))
      expect(flash[:alert]).to match(/only manage your own albums/i)
    end

    it "cannot edit, delete or read the album's guest analytics" do
      get edit_album_path(album)
      expect(response).to redirect_to(album_path(album))

      get view_events_album_path(album)
      expect(response).to redirect_to(album_path(album))

      expect { delete album_path(album) }.not_to change { Album.exists?(album.id) }
    end
  end

  describe "a family member and a closed album" do
    let(:closed) { create(:album, user: owner, privacy: "family", allow_contributions: false) }
    let!(:photo) { create(:photo, user: relative) }

    before { sign_in relative }

    it "refuses the add" do
      patch add_photo_album_path(closed, photo_id: photo.id)

      expect(response).to redirect_to(albums_path)
      expect(closed.reload.photos).to be_empty
    end

    it "still lets them view it" do
      get album_path(closed)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Add photos to this album")
    end
  end

  describe "someone outside the family" do
    let!(:photo) { create(:photo, user: outsider) }

    before { sign_in outsider }

    it "cannot add to the album even though it is open to its own family" do
      patch add_photo_album_path(album, photo_id: photo.id)

      expect(response).to redirect_to(albums_path)
      expect(album.reload.photos).to be_empty
    end
  end

  describe "the owner" do
    let!(:contributed) { create(:photo, user: relative) }

    before do
      album.add_photo(contributed)
      sign_in owner
    end

    it "can remove a photo a relative contributed" do
      delete remove_photo_album_path(album, photo_id: contributed.id)

      expect(album.reload.photos).to be_empty
    end

    it "is told on the album page who has added to it" do
      get album_path(album)

      expect(response.body).to include("They can add photos, too.")
      expect(response.body).to include(relative.display_name_or_full_name)
    end

    it "gets the contributions switch on the edit form" do
      get edit_album_path(album)

      expect(response.body).to include("Let your family add photos")
      expect(response.body).to include("album_allow_contributions")
    end

    it "turns contributions on from the edit form" do
      album.update!(allow_contributions: false)

      patch album_path(album), params: { album: { allow_contributions: "1" } }

      expect(album.reload.allow_contributions).to be true
    end
  end

  describe "bulk uploading into a shared album" do
    before { sign_in relative }

    it "accepts an album the family opened up" do
      post bulk_uploads_path, params: {
        bulk_upload: {
          album_id: album.id,
          images: [ Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/test_image.jpg"), "image/jpeg") ]
        }
      }

      expect(BulkUpload.last.album).to eq(album)
    end

    it "rejects an album nobody opened up" do
      closed = create(:album, user: owner, privacy: "family", allow_contributions: false)

      post bulk_uploads_path, params: {
        bulk_upload: {
          album_id: closed.id,
          images: [ Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/test_image.jpg"), "image/jpeg") ]
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(BulkUpload.count).to eq(0)
    end
  end
end
