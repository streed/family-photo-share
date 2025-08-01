require 'rails_helper'

RSpec.describe PhotosController, type: :controller do
  let(:user) { create(:user) }
  let(:photo) { create(:photo, user: user) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in user
  end

  describe 'GET #index' do
    context 'when user_id param is invalid' do
      it 'redirects with error message' do
        get :index, params: { user_id: 'invalid' }
        expect(response).to redirect_to(photos_path)
        expect(flash[:alert]).to eq('User not found.')
      end
    end
  end

  describe 'POST #create' do
    context 'with invalid photo data' do
      it 'renders new template with error' do
        post :create, params: { photo: { title: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        expect(flash.now[:alert]).to be_present
      end
    end

    context 'with valid photo data' do
      let(:image) { fixture_file_upload('spec/fixtures/test_image.jpg', 'image/jpeg') }

      it 'creates photo and redirects' do
        post :create, params: { photo: { title: 'Test Photo', image: image } }
        expect(response).to redirect_to(Photo.last)
        expect(flash[:notice]).to eq('Photo was successfully uploaded!')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when photo cannot be destroyed' do
      before do
        allow_any_instance_of(Photo).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)
      end

      it 'redirects with error message' do
        delete :destroy, params: { id: photo.id }
        expect(response).to redirect_to(photo)
        expect(flash[:alert]).to eq('Unable to delete photo. Please try again.')
      end
    end
  end
end
