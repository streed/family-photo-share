class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update]

  def show
    # Load user's accessible albums
    if @user == current_user
      # Show all own albums
      @albums = @user.albums.recent.includes(:cover_photo).limit(12)
    else
      # Show only family albums for family members, nothing for non-family users
      if current_user.family && current_user.family == @user.family
        @albums = @user.albums.family_albums.recent.includes(:cover_photo).limit(12)
      else
        @albums = Album.none
      end
    end
  end

  def edit
    # Only allow editing own profile
    redirect_to root_path unless @user == current_user
  end

  def update
    if @user.update(profile_params)
      redirect_to profile_path(@user), notice: 'Profile updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :display_name, :bio, :phone_number)
  end
end