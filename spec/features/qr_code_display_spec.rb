require 'rails_helper'

# The album page renders the QR code with class `qr-code-image-header` when the
# album has a cover photo and `qr-code-image-simple` otherwise — never the bare
# `qr-code-image` these specs used to look for. It also only renders the QR when
# the album actually has photos, so an empty album is not a valid fixture here.
RSpec.feature 'QR Code Display', type: :feature do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }

  before { sign_in user }

  def add_photo_to(album)
    photo = create(:photo, user: album.user)
    photo.image.attach(
      io: Rails.root.join("spec/fixtures/files/test_image.jpg").open,
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )
    album.add_photo(photo)
    photo
  end

  scenario 'QR code is displayed for externally shared albums' do
    add_photo_to(album)
    album.update!(allow_external_access: true, password: 'testpass')

    visit album_path(album)

    expect(page).to have_content('External Sharing')
    expect(page).to have_content('This album is shared externally')

    qr_image = page.find('img.qr-code-image-header, img.qr-code-image-simple', match: :first)
    expect(qr_image['alt']).to include(album.name)
    expect(qr_image['title']).to eq('Scan to view album')
    expect(qr_image['src']).to start_with('data:image/svg+xml;base64,')
    expect(page).to have_content('Scan to share')
  end

  scenario 'QR code is not displayed for non-shared albums' do
    add_photo_to(album)

    visit album_path(album)

    expect(page).not_to have_content('External Sharing')
    expect(page).not_to have_css('img.qr-code-image-header, img.qr-code-image-simple')
  end

  scenario 'QR code is not displayed for a shared album with no photos' do
    album.update!(allow_external_access: true, password: 'testpass')

    visit album_path(album)

    expect(album.photo_count).to eq(0)
    expect(page).not_to have_css('img.qr-code-image-header, img.qr-code-image-simple')
  end
end
