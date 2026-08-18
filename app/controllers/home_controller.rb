class HomeController < ApplicationController
  RECENT_PHOTO_COUNT = 12

  skip_before_action :authenticate_user!

  def index
    return unless user_signed_in?

    @family = current_user.family
    @recent_photos = current_user.recent_photos(RECENT_PHOTO_COUNT).to_a

    # Every tile on the dashboard asks for a short URL. Without this the grid
    # issues one lookup — and one INSERT — per photo on every page view.
    ShortUrl.warm_for_photos(@recent_photos, [ :thumbnail ])
  end
end
