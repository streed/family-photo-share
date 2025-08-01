require 'rails_helper'

RSpec.describe 'albums/show', type: :view do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }

  before do
    assign(:album, album)
    assign(:photos, [])
    allow(view).to receive(:current_user).and_return(user)
  end

  context 'when album has external access enabled' do
    before do
      album.update!(allow_external_access: true, password: 'testpass')
    end

    # Note: Cover photo test is complex due to Active Storage mocking.
    # Integration tests cover this functionality adequately.

    context 'without cover photo but with photos' do
      before do
        # Mock photo_count to return 1
        allow(album).to receive(:photo_count).and_return(1)
        assign(:album, album)
      end

      it 'displays QR code in simple layout when album has photos' do
        render

        expect(rendered).to have_css('.qr-code-container-simple')
        expect(rendered).to have_css('.qr-code-image-simple')
        expect(rendered).to have_content('Scan to share')
      end
    end

    context 'when album has no photos' do
      before do
        # Mock photo_count to return 0
        allow(album).to receive(:photo_count).and_return(0)
        assign(:album, album)
      end

      it 'does not display QR code when album is empty' do
        render

        expect(rendered).not_to have_css('.qr-code-container-simple')
        expect(rendered).not_to have_css('.qr-code-image-simple')
        expect(rendered).not_to have_content('Scan to share')
      end
    end
  end

  context 'when album does not have external access' do
    it 'does not display QR code' do
      render

      expect(rendered).not_to have_css('.album-header-qr')
      expect(rendered).not_to have_css('.qr-code-container-simple')
      expect(rendered).not_to have_content('Scan to share')
    end
  end
end
