require 'rails_helper'

RSpec.describe "Photos", type: :request do
  let(:user) { create(:user) }
  let(:photo) { create(:photo, user: user) }

  describe "GET /photos" do
    context "when user is signed in" do
      before { sign_in user }

      it "returns http success" do
        get photos_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get photos_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /photos/new" do
    context "when user is signed in" do
      before { sign_in user }

      it "returns http success" do
        get new_photo_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get new_photo_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /photos/:id" do
    context "when user is signed in" do
      before { sign_in user }

      it "returns http success" do
        get photo_path(photo)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get photo_path(photo)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /photos" do
    context "when user is signed in" do
      before { sign_in user }

      let(:valid_attributes) do
        {
          title: "Test Photo",
          description: "A test photo",
          image: fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.jpg'), 'image/jpeg')
        }
      end

      it "creates a new photo" do
        expect {
          post photos_path, params: { photo: valid_attributes }
        }.to change(Photo, :count).by(1)
      end

      it "redirects to the photo" do
        post photos_path, params: { photo: valid_attributes }
        expect(response).to redirect_to(Photo.last)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        post photos_path, params: { photo: { title: "Test" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /photos/:id/edit" do
    context "when user owns the photo" do
      before { sign_in user }

      it "returns http success" do
        get edit_photo_path(photo)
        expect(response).to have_http_status(:success)
      end
    end

    context "when user does not own the photo" do
      let(:other_user) { create(:user) }
      before { sign_in other_user }

      it "redirects to photos index" do
        get edit_photo_path(photo)
        expect(response).to redirect_to(photos_path)
      end
    end
  end

  describe "DELETE /photos/:id" do
    context "when user owns the photo" do
      before { sign_in user }

      it "deletes the photo" do
        photo # create the photo
        expect {
          delete photo_path(photo)
        }.to change(Photo, :count).by(-1)
      end

      it "redirects to photos index" do
        delete photo_path(photo)
        expect(response).to redirect_to(photos_path)
      end
    end

    context "when user does not own the photo" do
      let(:other_user) { create(:user) }
      before { sign_in other_user }

      it "redirects to photos index" do
        delete photo_path(photo)
        expect(response).to redirect_to(photos_path)
      end
    end
  end

  describe "DELETE /photos/:id as JSON (batch uploader)" do
    it "deletes your photo and answers 204 instead of redirecting" do
      sign_in user
      photo
      expect { delete photo_path(photo), as: :json }.to change(Photo, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "refuses someone else's photo with 403" do
      sign_in create(:user)
      photo
      expect { delete photo_path(photo), as: :json }.not_to change(Photo, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /photos/finalize" do
    let(:album) { create(:album, user: user) }
    let(:first) { create(:photo, user: user) }
    let(:second) { create(:photo, user: user) }

    before { sign_in user }

    it "applies titles and adds the photos to the album in the order given" do
      post finalize_photos_path, params: {
        album_id: album.id,
        photos: [
          { id: second.id, title: "Second", description: "" },
          { id: first.id, title: "First", description: "Hi" }
        ]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(first.reload.title).to eq("First")
      expect(first.description).to eq("Hi")
      expect(album.album_photos.ordered.pluck(:photo_id)).to eq([ second.id, first.id ])
    end

    it "works without an album" do
      post finalize_photos_path, params: { photos: [ { id: first.id, title: "Solo" } ] }, as: :json
      expect(response).to have_http_status(:ok)
      expect(first.reload.title).to eq("Solo")
    end

    it "reports photos that aren't yours instead of touching them" do
      stranger = create(:photo, user: create(:user), title: "Theirs")
      post finalize_photos_path, params: { album_id: album.id, photos: [ { id: stranger.id, title: "Mine now" } ] }, as: :json

      expect(response.parsed_body["failed"]).to eq([ stranger.id ])
      expect(stranger.reload.title).to eq("Theirs")
      expect(album.album_photos).to be_empty
    end

    it "refuses an album the user can't add to" do
      post finalize_photos_path, params: { album_id: create(:album).id, photos: [ { id: first.id, title: "x" } ] }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
