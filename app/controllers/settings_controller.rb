class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def update_profile
    @user = current_user

    if @user.update(profile_params)
      redirect_to settings_path, notice: "Profile updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_account
    @user = current_user

    # Handle account updates (email/password changes)
    if account_params[:password].blank?
      # If no password change, just update email (may require current password for email changes)
      if account_params[:email] != @user.email
        # Email change requires current password verification
        if @user.valid_password?(account_params[:current_password])
          if @user.update(account_params.except(:password, :password_confirmation, :current_password))
            redirect_to settings_path, notice: "Account updated successfully."
          else
            render :show, status: :unprocessable_entity
          end
        else
          @user.errors.add(:current_password, "is incorrect")
          render :show, status: :unprocessable_entity
        end
      else
        # No email change, just update other allowed fields
        if @user.update(account_params.except(:password, :password_confirmation, :current_password, :email))
          redirect_to settings_path, notice: "Account updated successfully."
        else
          render :show, status: :unprocessable_entity
        end
      end
    else
      # Password change requires current password verification
      if @user.update_with_password(account_params)
        bypass_sign_in(@user) # Keep user signed in after password change
        redirect_to settings_path, notice: "Account updated successfully."
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  def destroy_account
    @user = current_user

    if @user.valid_password?(params[:current_password])
      @user.destroy
      redirect_to root_path, notice: "Your account has been successfully deleted."
    else
      @user.errors.add(:current_password, "is incorrect")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :display_name, :bio, :phone_number)
  end

  def account_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password)
  end
end
