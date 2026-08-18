require 'rails_helper'

RSpec.describe "Family Edit Functionality", type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user) }
  let(:non_member) { create(:user) }
  let(:family) { create(:family, created_by: admin_user) }

  before do
    # Set up family memberships
    family.family_memberships.find_by(user: admin_user).update!(role: 'admin')
    family.family_memberships.create!(user: user, role: 'member')
  end

  describe "GET /families/:id/edit" do
    context "when user is not authenticated" do
      it "redirects to login" do
        get edit_family_path(family)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is authenticated" do
      context "as an admin" do
        before { sign_in admin_user }

        it "returns success and shows the edit form" do
          get edit_family_path(family)
          expect(response).to have_http_status(:success)
          expect(response.body).to include("Edit family")
          expect(response.body).to include(ERB::Util.html_escape(family.name))
        end
      end

      context "as a regular member" do
        before { sign_in user }

        it "redirects with an alert" do
          get edit_family_path(family)
          expect(response).to redirect_to(family_path(family))
          expect(flash[:alert]).to eq("Only family admins can perform this action.")
        end
      end

      context "as a non-member" do
        before { sign_in non_member }

        it "redirects to families index" do
          get edit_family_path(family)
          expect(response).to redirect_to(families_path)
          expect(flash[:alert]).to eq("You are not a member of this family.")
        end
      end
    end
  end

  describe "PATCH /families/:id" do
    let(:valid_attributes) { { name: "Updated Family Name", description: "Updated description" } }
    let(:invalid_attributes) { { name: "" } }

    context "when user is not authenticated" do
      it "redirects to login" do
        patch family_path(family), params: { family: valid_attributes }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is authenticated" do
      context "as an admin" do
        before { sign_in admin_user }

        context "with valid parameters" do
          it "updates the family and redirects" do
            patch family_path(family), params: { family: valid_attributes }
            expect(response).to redirect_to(family_path(family))
            expect(flash[:notice]).to eq("Family was successfully updated!")

            family.reload
            expect(family.name).to eq("Updated Family Name")
            expect(family.description).to eq("Updated description")
          end
        end

        context "with invalid parameters" do
          it "renders the edit template with errors" do
            patch family_path(family), params: { family: invalid_attributes }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.body).to include("error")
          end
        end
      end

      context "as a regular member" do
        before { sign_in user }

        it "redirects with an alert" do
          patch family_path(family), params: { family: valid_attributes }
          expect(response).to redirect_to(family_path(family))
          expect(flash[:alert]).to eq("Only family admins can perform this action.")

          family.reload
          expect(family.name).not_to eq("Updated Family Name")
        end
      end

      context "as a non-member" do
        before { sign_in non_member }

        it "redirects to families index" do
          patch family_path(family), params: { family: valid_attributes }
          expect(response).to redirect_to(families_path)
          expect(flash[:alert]).to eq("You are not a member of this family.")
        end
      end
    end
  end

  describe "Family deletion" do
    # A user may only belong to one family (FamilyMembership validates user_id
    # uniqueness), so the solo family needs its own creator — reusing admin_user
    # here made Family#add_creator_as_admin fail validation.
    let(:solo_creator) { create(:user) }

    context "when user is the creator and only member" do
      let(:solo_family) { create(:family, created_by: solo_creator) }

      before do
        sign_in solo_creator
        # Ensure only one member
        solo_family.family_memberships.where.not(user: solo_creator).destroy_all
      end

      it "shows delete button on edit page" do
        get edit_family_path(solo_family)
        expect(response.body).to include("Delete family")
      end

      it "allows deletion" do
        expect {
          delete family_path(solo_family)
        }.to change(Family, :count).by(-1)

        expect(response).to redirect_to(families_path)
        expect(flash[:notice]).to eq("Family was successfully deleted!")
      end
    end

    context "when family has multiple members" do
      before { sign_in admin_user }

      it "does not show delete button on edit page" do
        get edit_family_path(family)
        expect(response.body).not_to include("Delete family")
      end
    end
  end
end
