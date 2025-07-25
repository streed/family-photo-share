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
  
  describe "Password reset error handling" do
    it "shows success message for valid email" do
      user = create(:user)
      
      post user_password_path, params: {
        user: { email: user.email }
      }
      
      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("Check your email for password reset instructions")
    end
    
    it "shows generic message for non-existent email" do
      post user_password_path, params: {
        user: { email: "nonexistent@example.com" }
      }
      
      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("If an account exists with this email")
    end
  end
end