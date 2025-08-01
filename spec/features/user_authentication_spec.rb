require 'rails_helper'

RSpec.feature 'User Authentication', type: :feature do
  scenario 'User signs up successfully' do
    visit new_user_registration_path

    fill_in 'First name', with: 'John'
    fill_in 'Last name', with: 'Doe'
    fill_in 'Email', with: 'john@example.com'
    fill_in 'Password', with: 'password123'
    fill_in 'Password confirmation', with: 'password123'

    click_button 'Sign up'

    expect(page).to have_content('A message with a confirmation link has been sent')
  end

  scenario 'User signs in successfully' do
    user = create(:user, email: 'john@example.com')

    visit new_user_session_path

    fill_in 'Email', with: 'john@example.com'
    fill_in 'Password', with: 'password123'

    click_button 'Log in'

    expect(page).to have_content('Signed in successfully')
  end
end
