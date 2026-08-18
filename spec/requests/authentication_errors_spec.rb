require 'rails_helper'

RSpec.describe "Authentication Errors", type: :request do
  describe "Login error handling" do
    let(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with invalid credentials" do
      it "shows an error message for incorrect password" do
        post user_session_path, params: {
          user: { email: user.email, password: "wrongpassword" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Invalid email or password")
      end

      it "shows an error message for non-existent email" do
        post user_session_path, params: {
          user: { email: "nonexistent@example.com", password: "password123" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Invalid email or password")
      end
    end

    context "rate limiting" do
      it "shows warning after multiple failed attempts" do
        # Simulate 3 failed login attempts
        3.times do
          post user_session_path, params: {
            user: { email: user.email, password: "wrongpassword" }
          }
        end

        expect(response.body).to include("You have 2 attempts remaining")
      end

      it "locks account after maximum failed attempts" do
        # Simulate 5 failed login attempts
        5.times do
          post user_session_path, params: {
            user: { email: user.email, password: "wrongpassword" }
          }
        end

        # Try one more time
        post user_session_path, params: {
          user: { email: user.email, password: "wrongpassword" }
        }

        expect(response.body).to include("Too many failed login attempts")
        expect(response.body).to include("temporarily locked")
      end
    end
  end

  describe "Registration error handling" do
    # These are about the form's validation messages, not about who may reach it:
    # open sign-up is off by default (see spec/requests/public_signup_spec.rb).
    before { allow(PublicSignup).to receive(:enabled?).and_return(true) }

    context "with invalid data" do
      it "shows error for duplicate email" do
        existing_user = create(:user)

        post user_registration_path, params: {
          user: {
            first_name: "Test",
            last_name: "User",
            email: existing_user.email,
            password: "password123",
            password_confirmation: "password123"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Email has already been taken")
      end

      it "shows error for password mismatch" do
        post user_registration_path, params: {
          user: {
            first_name: "Test",
            last_name: "User",
            email: "newuser@example.com",
            password: "password123",
            password_confirmation: "differentpassword"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Password confirmation doesn&#39;t match")
      end
    end
  end

  # Devise runs in paranoid mode, so password reset deliberately responds
  # identically for known and unknown addresses — that is what stops an attacker
  # from using this form to discover which emails have accounts.
  describe "Password reset error handling" do
    it "shows the generic message for a valid email" do
      user = create(:user)

      post user_password_path, params: {
        user: { email: user.email }
      }

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("If an account exists with this email")
    end

    it "shows the same generic message for a non-existent email" do
      post user_password_path, params: {
        user: { email: "nonexistent@example.com" }
      }

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("If an account exists with this email")
    end

    it "still sends the reset email when the account exists" do
      user = create(:user)

      expect {
        post user_password_path, params: { user: { email: user.email } }
      }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it "sends nothing when the account does not exist" do
      expect {
        post user_password_path, params: { user: { email: "nonexistent@example.com" } }
      }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
