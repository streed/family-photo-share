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
end
