require 'rails_helper'

RSpec.feature 'QR Code Positioning', type: :feature, js: false do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }

  before do
    sign_in user
  end

  scenario 'QR code appears in the album header when external sharing is enabled and album has photos' do
    # Enable external sharing for the album and add a photo
    album.update!(allow_external_access: true, password: 'testpass')
    photo = create(:photo, user: user)
    album.add_photo(photo)

    visit album_path(album)

    # Should show QR code elements (either header or simple version)
    expect(page).to have_css('.qr-code-image')
    expect(page).to have_content('Scan to share')

    # It lives in the sharing card, next to the link it encodes.
    expect(page).to have_content('Share by link')
  end

  scenario 'QR code does not appear when external sharing is disabled' do
    # Album without external sharing
    visit album_path(album)

    # Should not show QR code
    expect(page).not_to have_css('.qr-code-image')
    expect(page).not_to have_content('Scan to share')
  end

  scenario 'QR code does not appear when external sharing is enabled but album has no photos' do
    # Enable external sharing but don't add any photos
    album.update!(allow_external_access: true, password: 'testpass')

    visit album_path(album)

    # Should not show QR code because no photos exist
    expect(page).not_to have_css('.qr-code-image')
    expect(page).not_to have_content('Scan to share')
  end
end
