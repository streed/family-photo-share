require 'rails_helper'

RSpec.describe "BulkUploads", type: :request do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }
  
  before do
    sign_in user
  end
  
  describe "GET /bulk_uploads/new" do
    it "returns http success" do
      get new_bulk_upload_path
      expect(response).to have_http_status(:success)
    end
    
    it "assigns a new bulk upload" do
      get new_bulk_upload_path
      expect(assigns(:bulk_upload)).to be_a_new(BulkUpload)
    end
  end
  
  describe "GET /bulk_uploads" do
    it "returns http success" do
      get bulk_uploads_path
      expect(response).to have_http_status(:success)
    end
    
    it "displays user's bulk uploads" do
      bulk_upload = create(:bulk_upload, user: user)
      other_bulk_upload = create(:bulk_upload)
      
      get bulk_uploads_path
      
      expect(assigns(:bulk_uploads)).to include(bulk_upload)
      expect(assigns(:bulk_uploads)).not_to include(other_bulk_upload)
    end
  end
  
  describe "GET /bulk_uploads/:id" do
    let(:bulk_upload) { create(:bulk_upload, user: user) }
    
    it "returns http success for own bulk upload" do
      get bulk_upload_path(bulk_upload)
      expect(response).to have_http_status(:success)
    end
    
    it "displays the bulk upload" do
      get bulk_upload_path(bulk_upload)
      expect(assigns(:bulk_upload)).to eq(bulk_upload)
    end
  end
  
  describe "POST /bulk_uploads" do
    let(:test_image) { fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.jpg'), 'image/jpeg') }
    
    context "with valid images" do
      it "creates a new bulk upload" do
        expect {
          post bulk_uploads_path, params: {
            bulk_upload: {
              album_id: album.id,
              images: [test_image]
            }
          }
        }.to change(BulkUpload, :count).by(1)
      end
      
      it "redirects to the bulk upload show page" do
        post bulk_uploads_path, params: {
          bulk_upload: {
            album_id: album.id,
            images: [test_image]
          }
        }
        
        expect(response).to redirect_to(bulk_upload_path(BulkUpload.last))
      end
      
      it "enqueues background processing job" do
        expect(BulkUploadProcessingJob).to receive(:perform_async)
        
        post bulk_uploads_path, params: {
          bulk_upload: {
            album_id: album.id,
            images: [test_image]
          }
        }
      end
    end
    
    context "without album" do
      it "creates bulk upload without album" do
        post bulk_uploads_path, params: {
          bulk_upload: {
            album_id: '',
            images: [test_image]
          }
        }
        
        bulk_upload = BulkUpload.last
        expect(bulk_upload.album).to be_nil
        expect(response).to redirect_to(bulk_upload_path(bulk_upload))
      end
    end
  end
  
  context "when not signed in" do
    before { sign_out user }
    
    it "redirects to sign in for new" do
      get new_bulk_upload_path
      expect(response).to redirect_to(new_user_session_path)
    end
    
    it "redirects to sign in for index" do
      get bulk_uploads_path
      expect(response).to redirect_to(new_user_session_path)
    end
    
    it "redirects to sign in for show" do
      bulk_upload = create(:bulk_upload, user: user)
      get bulk_upload_path(bulk_upload)
      expect(response).to redirect_to(new_user_session_path)
    end
    
    it "redirects to sign in for create" do
      post bulk_uploads_path, params: { bulk_upload: { images: [] } }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end