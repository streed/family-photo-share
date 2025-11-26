require 'rails_helper'

RSpec.describe AlbumsController, type: :controller do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in user
  end

  describe 'POST #add_photos' do
    let!(:photo1) { create(:photo, user: user) }
    let!(:photo2) { create(:photo, user: user) }
    let!(:photo3) { create(:photo, user: user) }

    context 'with valid photo_ids' do
      it 'adds multiple photos to album' do
        expect {
          post :add_photos, params: { id: album.id, photo_ids: [photo1.id, photo2.id, photo3.id] }
        }.to change { album.reload.album_photos.count }.by(3)
      end

      it 'redirects to album with success notice' do
        post :add_photos, params: { id: album.id, photo_ids: [photo1.id, photo2.id] }
        expect(response).to redirect_to(album_path(album))
        expect(flash[:notice]).to eq('Successfully added 2 photos to album!')
      end

      it 'uses correct pluralization for single photo' do
        post :add_photos, params: { id: album.id, photo_ids: [photo1.id] }
        expect(flash[:notice]).to eq('Successfully added 1 photo to album!')
      end
    end

    context 'with empty photo_ids' do
      it 'does not add photos' do
        expect {
          post :add_photos, params: { id: album.id, photo_ids: [] }
        }.not_to change { album.reload.album_photos.count }
      end

      it 'redirects with alert message' do
        post :add_photos, params: { id: album.id, photo_ids: [] }
        expect(response).to redirect_to(album_path(album))
        expect(flash[:alert]).to eq('No photos selected.')
      end
    end

    context 'with photos from another user' do
      let(:other_user) { create(:user) }
      let(:other_photo) { create(:photo, user: other_user) }

      it 'does not add any photos' do
        expect {
          post :add_photos, params: { id: album.id, photo_ids: [photo1.id, other_photo.id] }
        }.not_to change { album.reload.album_photos.count }
      end

      it 'redirects with permission error' do
        post :add_photos, params: { id: album.id, photo_ids: [photo1.id, other_photo.id] }
        expect(response).to redirect_to(album_path(album))
        expect(flash[:alert]).to eq("Some photos were not found or you don't have permission to add them.")
      end
    end

    context 'with duplicate photos' do
      before do
        album.add_photo(photo1)
      end

      it 'only adds new photos' do
        expect {
          post :add_photos, params: { id: album.id, photo_ids: [photo1.id, photo2.id, photo3.id] }
        }.to change { album.reload.album_photos.count }.by(2)
      end

      it 'reports correct count of added photos' do
        post :add_photos, params: { id: album.id, photo_ids: [photo1.id, photo2.id] }
        expect(flash[:notice]).to eq('Successfully added 1 photo to album!')
      end
    end

    context 'when all photos are already in album' do
      before do
        album.add_photo(photo1)
        album.add_photo(photo2)
      end

      it 'does not add duplicate photos' do
        expect {
          post :add_photos, params: { id: album.id, photo_ids: [photo1.id, photo2.id] }
        }.not_to change { album.reload.album_photos.count }
      end

      it 'redirects with alert about no new photos' do
        post :add_photos, params: { id: album.id, photo_ids: [photo1.id, photo2.id] }
        expect(response).to redirect_to(album_path(album))
        expect(flash[:alert]).to eq('No new photos were added. They may already be in the album.')
      end
    end

    context 'when user does not own the album' do
      let(:other_user) { create(:user) }
      let(:other_album) { create(:album, user: other_user) }

      it 'redirects to album with unauthorized message' do
        post :add_photos, params: { id: other_album.id, photo_ids: [photo1.id] }
        expect(response).to redirect_to(album_path(other_album))
        expect(flash[:alert]).to eq('You can only manage your own albums.')
      end
    end

    context 'with invalid photo ids' do
      it 'handles non-existent photo ids gracefully' do
        expect {
          post :add_photos, params: { id: album.id, photo_ids: [99999, 88888] }
        }.not_to change { album.reload.album_photos.count }
        
        expect(response).to redirect_to(album_path(album))
        expect(flash[:alert]).to eq("Some photos were not found or you don't have permission to add them.")
      end
    end

    context 'when exception occurs' do
      before do
        allow_any_instance_of(Album).to receive(:add_photo).and_raise(StandardError.new('Database error'))
      end

      it 'handles errors gracefully' do
        post :add_photos, params: { id: album.id, photo_ids: [photo1.id] }
        expect(response).to redirect_to(album_path(album))
        expect(flash[:alert]).to eq('An error occurred while adding photos.')
      end
    end
  end

  describe 'PATCH #add_photo' do
    let(:photo) { create(:photo, user: user) }

    context 'with valid photo' do
      it 'adds single photo to album' do
        expect {
          patch :add_photo, params: { id: album.id, photo_id: photo.id }
        }.to change { album.reload.album_photos.count }.by(1)
      end

      it 'redirects with success notice' do
        patch :add_photo, params: { id: album.id, photo_id: photo.id }
        expect(response).to redirect_to(album_path(album))
        expect(flash[:notice]).to eq('Photo added to album!')
      end
    end

    context 'with photo already in album' do
      before do
        album.add_photo(photo)
      end

      it 'does not add duplicate' do
        expect {
          patch :add_photo, params: { id: album.id, photo_id: photo.id }
        }.not_to change { album.reload.album_photos.count }
      end

      it 'redirects with alert' do
        patch :add_photo, params: { id: album.id, photo_id: photo.id }
        expect(response).to redirect_to(album_path(album))
        expect(flash[:alert]).to eq('Photo is already in this album.')
      end
    end

    context 'with photo from another user' do
      let(:other_user) { create(:user) }
      let(:other_photo) { create(:photo, user: other_user) }

      it 'does not add photo' do
        expect {
          patch :add_photo, params: { id: album.id, photo_id: other_photo.id }
        }.not_to change { album.reload.album_photos.count }
      end

      it 'redirects with permission error' do
        patch :add_photo, params: { id: album.id, photo_id: other_photo.id }
        expect(response).to redirect_to(album_path(album))
        expect(flash[:alert]).to eq('You can only add your own photos to albums.')
      end
    end

    context 'with invalid photo id' do
      it 'handles non-existent photo gracefully' do
        expect {
          patch :add_photo, params: { id: album.id, photo_id: 99999 }
        }.not_to change { album.reload.album_photos.count }
        
        expect(response).to redirect_to(album_path(album))
        expect(flash[:alert]).to eq('Photo not found.')
      end
    end
  end
end
