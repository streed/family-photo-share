require 'rails_helper'

RSpec.describe "Albums", type: :request do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }

  describe "GET /albums" do
    context "when user is signed in" do
      before { sign_in user }

      it "returns http success" do
        get albums_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get albums_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /albums/new" do
    context "when user is signed in" do
      before { sign_in user }

      it "returns http success" do
        get new_album_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get new_album_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /albums/:id" do
    context "when user owns the album" do
      before { sign_in user }

      it "returns http success" do
        get album_path(album)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user does not have access" do
      let(:other_user) { create(:user) }
      before { sign_in other_user }

      it "redirects to albums index" do
        get album_path(album)
        expect(response).to redirect_to(albums_path)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get album_path(album)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /albums" do
    context "when user is signed in" do
      before { sign_in user }

      let(:valid_attributes) do
        {
          name: "Test Album",
          description: "A test album",
          privacy: "private"
        }
      end

      it "creates a new album" do
        expect {
          post albums_path, params: { album: valid_attributes }
        }.to change(Album, :count).by(1)
      end

      it "redirects to the album" do
        post albums_path, params: { album: valid_attributes }
        expect(response).to redirect_to(Album.last)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        post albums_path, params: { album: { name: "Test" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /albums/:id/edit" do
    context "when user owns the album" do
      before { sign_in user }

      it "returns http success" do
        get edit_album_path(album)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user does not own the album" do
      let(:other_user) { create(:user) }
      before { sign_in other_user }

      it "redirects to album" do
        get edit_album_path(album)
        expect(response).to redirect_to(album_path(album))
      end
    end
  end

  describe "DELETE /albums/:id" do
    context "when user owns the album" do
      before { sign_in user }

      it "deletes the album" do
        album # create the album
        expect {
          delete album_path(album)
        }.to change(Album, :count).by(-1)
      end

      it "redirects to albums index" do
        delete album_path(album)
        expect(response).to redirect_to(albums_path)
      end
    end

    context "when user does not own the album" do
      let(:other_user) { create(:user) }
      before { sign_in other_user }

      it "redirects to album" do
        delete album_path(album)
        expect(response).to redirect_to(album_path(album))
      end
    end
  end

  describe "PATCH /albums/:id/add_photo" do
    let(:photo) { create(:photo, user: user) }

    context "when user owns the album" do
      before { sign_in user }

      it "adds photo to album" do
        expect {
          patch add_photo_album_path(album, photo_id: photo.id)
        }.to change(album.album_photos, :count).by(1)
      end

      it "redirects to album" do
        patch add_photo_album_path(album, photo_id: photo.id)
        expect(response).to redirect_to(album_path(album))
      end
    end
  end
end
