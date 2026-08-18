require 'rails_helper'

# Creating an account is invitation-only unless the operator sets
# ALLOW_PUBLIC_SIGNUP. The thing these specs mostly guard is the exception:
# turning open sign-up off must not take the family invitation flow down with it.
RSpec.describe "Public sign-up", type: :request do
  let(:valid_params) do
    {
      user: {
        first_name: "Jo",
        last_name: "Reed",
        email: "jo@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }
  end

  describe "PublicSignup.enabled?" do
    around do |example|
      original = ENV[PublicSignup::ENV_VAR]
      example.run
      ENV[PublicSignup::ENV_VAR] = original
    end

    it "is off when the variable is unset, empty or a false-ish value" do
      [ nil, "", "false", "0", "off" ].each do |value|
        ENV[PublicSignup::ENV_VAR] = value
        expect(PublicSignup.enabled?).to be(false), "expected #{value.inspect} to leave sign-up closed"
      end
    end

    it "is on for the usual ways of saying yes" do
      [ "true", "1", "yes", "on" ].each do |value|
        ENV[PublicSignup::ENV_VAR] = value
        expect(PublicSignup.enabled?).to be(true), "expected #{value.inspect} to open sign-up"
      end
    end
  end

  context "when open sign-up is off (the default)" do
    it "turns away the sign-up form" do
      get new_user_registration_path

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to match(/invitation only/i)
    end

    it "refuses to create an account, even posted directly" do
      expect { post user_registration_path, params: valid_params }.not_to change(User, :count)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "offers no way to sign up from the landing page" do
      get root_path

      expect(response.body).not_to include(new_user_registration_path)
      expect(response.body).to include("by invitation")
    end

    it "still lets people sign in" do
      create(:user, email: "jo@example.com", password: "password123")

      post user_session_path, params: { user: { email: "jo@example.com", password: "password123" } }

      expect(response).to redirect_to(root_path)
    end
  end

  context "when open sign-up is on" do
    before { allow(PublicSignup).to receive(:enabled?).and_return(true) }

    it "serves the sign-up form" do
      get new_user_registration_path

      expect(response).to have_http_status(:success)
    end

    it "creates the account" do
      expect { post user_registration_path, params: valid_params }.to change(User, :count).by(1)
    end

    it "offers it on the landing page" do
      get root_path

      expect(response.body).to include(new_user_registration_path)
    end
  end

  describe "an invited person, with open sign-up off" do
    let(:family) { create(:family) }
    let(:invitation) do
      create(:family_invitation, family: family, inviter: family.created_by, email: "invited@example.com")
    end

    let(:invited_params) do
      valid_params.deep_merge(user: { email: "invited@example.com" })
    end

    it "can open the sign-up form through their invitation link" do
      get invitation_signup_path(invitation.token)

      expect(response).to have_http_status(:success)
    end

    it "can create their account and lands in the family" do
      get invitation_signup_path(invitation.token)

      expect { post user_registration_path, params: invited_params }.to change(User, :count).by(1)

      expect(User.find_by(email: "invited@example.com").family).to eq(family)
      expect(invitation.reload).to be_accepted
    end

    it "is offered the account link on the sign-in page after following the invitation" do
      patch accept_invitation_path(invitation.token) # stashes the token, then asks them to sign in
      get new_user_session_path

      expect(response.body).to include(invitation_signup_path(invitation.token))
    end

    it "gets nowhere with an expired invitation" do
      invitation.update!(expires_at: 1.day.ago)

      get invitation_signup_path(invitation.token)

      expect(response).to redirect_to(root_path)
      expect { post user_registration_path, params: invited_params }.not_to change(User, :count)
    end
  end
end
