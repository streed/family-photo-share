require 'rails_helper'

RSpec.describe "Photo library paging", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /photos" do
    it "tells the user how many photos exist, not just how many are shown" do
      create_list(:photo, 3, user: user)

      get photos_path

      expect(response.body).to include("Showing 3 of 3")
    end

    it "pages instead of silently truncating a large library" do
      create_list(:photo, PhotosController::PER_PAGE + 5, user: user)
      total = PhotosController::PER_PAGE + 5

      get photos_path

      expect(response.body).to include("Showing #{PhotosController::PER_PAGE} of #{total}")
      expect(response.body).to include("Page 1 of 2")
      expect(response.body).to include(photos_path(page: 2))
    end

    it "serves the remainder on the second page" do
      create_list(:photo, PhotosController::PER_PAGE + 5, user: user)

      get photos_path(page: 2)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Page 2 of 2")
    end

    it "does not blow up on a page beyond the end" do
      create_list(:photo, 3, user: user)

      get photos_path(page: 99)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Nothing on this page")
    end

    it "keeps search filters when paging" do
      create_list(:photo, PhotosController::PER_PAGE + 2, user: user, location: "Lisbon")
      create(:photo, user: user, location: "Oslo")

      get photos_path(location: "Lisbon")

      expect(response.body).to include("Showing #{PhotosController::PER_PAGE} of #{PhotosController::PER_PAGE + 2}")
      expect(response.body).to include("location=Lisbon")
    end
  end

  describe "PATCH /photos/:id/retry_processing" do
    let(:photo) { create(:photo, user: user) }

    it "requeues a failed photo" do
      photo.update_columns(processing_state: "failed", processing_error: "boom", processing_attempts: 1)
      allow(ImageProcessingJob).to receive(:perform_async)

      patch retry_processing_photo_path(photo)

      expect(response).to redirect_to(photo_path(photo))
      expect(photo.reload.processing_state).to eq("pending")
      expect(ImageProcessingJob).to have_received(:perform_async).with(photo.id)
    end

    it "refuses when the photo is not in a failed state" do
      patch retry_processing_photo_path(photo)

      expect(response).to redirect_to(photo_path(photo))
      expect(photo.reload.processing_state).to eq("pending")
    end

    it "will not let a stranger retry someone else's photo" do
      other = create(:photo, user: create(:user))
      other.update_columns(processing_state: "failed", processing_attempts: 1)

      patch retry_processing_photo_path(other)

      expect(response).to redirect_to(photos_path)
      expect(other.reload.processing_state).to eq("failed")
    end
  end
end
