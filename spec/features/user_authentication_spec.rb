require 'rails_helper'

# These drive the real forms, so the field labels and button text below must
# match app/views/devise/*. The previous version used Devise's stock labels
# ("Password confirmation", "Sign up", "Log in"), none of which appear in this
# app's customised forms.
RSpec.feature 'User Authentication', type: :feature do
  scenario 'User signs up successfully' do
    visit new_user_registration_path

    fill_in 'First Name', with: 'John'
    fill_in 'Last Name', with: 'Doe'
    fill_in 'Email Address', with: 'john@example.com'
    fill_in 'Password', with: 'password123'
    fill_in 'Confirm Password', with: 'password123'

    click_button 'Create Account'

    # No :confirmable module — a new account is signed in immediately.
    expect(User.find_by(email: 'john@example.com')).to be_present
    expect(page).to have_content('Family Memories')
  end

  scenario 'User signs in successfully' do
    create(:user, email: 'john@example.com', password: 'password123')

    visit new_user_session_path

    fill_in 'Email Address', with: 'john@example.com'
    fill_in 'Password', with: 'password123'

    click_button 'Sign In'

    expect(page).to have_content("You've signed in successfully")
  end

  scenario 'User sees an error for a wrong password' do
    create(:user, email: 'john@example.com', password: 'password123')

    visit new_user_session_path

    fill_in 'Email Address', with: 'john@example.com'
    fill_in 'Password', with: 'nope-wrong-password'

    click_button 'Sign In'

    expect(page).to have_content('Invalid email or password')
  end
end
