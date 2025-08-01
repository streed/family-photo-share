class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    if user_signed_in?
      @family = current_user.family
      @recent_photos = current_user.recent_photos(6) if current_user.photo_count > 0
    end
  end
end
