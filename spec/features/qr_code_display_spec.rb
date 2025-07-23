require 'rails_helper'

RSpec.feature 'QR Code Display', type: :feature do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }
  
  before do
    sign_in user
  end
  
  scenario 'QR code is displayed for externally shared albums' do
    # Enable external sharing for the album
    album.update!(allow_external_access: true, password: 'testpass')
    
    visit album_path(album)
    
    # Should show the external sharing section
    expect(page).to have_content('External Sharing')
    expect(page).to have_content('This album is shared externally')
    
    # Should have QR code image
    expect(page).to have_css('img.qr-code-image')
    expect(page).to have_content('Scan with phone')
    
    # QR code should have proper attributes
    qr_image = page.find('img.qr-code-image')
    expect(qr_image['alt']).to include(album.name)
    expect(qr_image['title']).to eq('Scan to view album')
    expect(qr_image['src']).to start_with('data:image/svg+xml;base64,')
  end
  
  scenario 'QR code is not displayed for non-shared albums' do
    # Album without external sharing
    visit album_path(album)
    
    # Should not show external sharing section
    expect(page).not_to have_content('External Sharing')
    expect(page).not_to have_css('img.qr-code-image')
    expect(page).not_to have_content('Scan with phone')
  end
  
  scenario 'QR code is responsive on mobile viewport', js: true do
    album.update!(allow_external_access: true, password: 'testpass')
    
    # Simulate mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)
    
    visit album_path(album)
    
    # QR code should still be visible and properly sized
    expect(page).to have_css('img.qr-code-image')
    
    qr_container = page.find('.qr-code-container')
    expect(qr_container).to be_visible
  end
end