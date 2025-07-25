require 'rails_helper'

RSpec.feature 'Photo Optional Title', type: :feature, js: false do
  let(:user) { create(:user) }
  
  before do
    sign_in user
  end
  
  scenario 'User can upload a photo without a title' do
    visit new_photo_path
    
    # Upload an image without filling in the title
    attach_file 'photo[image]', Rails.root.join('spec/fixtures/files/test_image.jpg')
    fill_in 'photo[description]', with: 'A beautiful sunset'
    fill_in 'photo[location]', with: 'California'
    
    click_button 'Upload Photo'
    
    # Should successfully create the photo
    expect(page).to have_current_path(photo_path(Photo.last))
    expect(page).to have_content('Untitled Photo')
    expect(page).to have_content('A beautiful sunset')
    expect(page).to have_content('California')
  end
  
  scenario 'Photo index shows "Untitled Photo" for photos without titles' do
    # Create a photo without a title
    photo_without_title = create(:photo, :without_title, user: user)
    photo_with_title = create(:photo, title: 'My Great Photo', user: user)
    
    visit photos_path
    
    # Should show both photos with appropriate titles
    expect(page).to have_content('Untitled Photo')
    expect(page).to have_content('My Great Photo')
  end
  
  scenario 'Album view shows "Untitled Photo" for photos without titles' do
    album = create(:album, user: user)
    photo_without_title = create(:photo, :without_title, user: user)
    photo_with_title = create(:photo, title: 'Beach Day', user: user)
    
    album.add_photo(photo_without_title)
    album.add_photo(photo_with_title)
    
    visit album_path(album)
    
    # Should show both photos with appropriate titles
    expect(page).to have_content('Untitled Photo')
    expect(page).to have_content('Beach Day')
  end
end