module GuestSessionTracking
  extend ActiveSupport::Concern

  private

  # Writes the pair of cookies that carry a guest's access to a shared album.
  #
  # Call this every time the session's expiry moves. The signed cookie is what
  # actually authorizes photo requests, and it used to be issued once, at
  # sign-in, with a fixed expiry, while the database session went on being
  # extended on each page view. The two drifted apart, so an active guest lost
  # access at a fixed wall-clock time no matter what they were doing: the album
  # page bounced to the password form, and every photo tile — which cannot
  # follow a redirect — turned into a 403.
  def write_guest_session_cookies!(access_session)
    cookies.signed[:album_access] = {
      value: {
        "token" => access_session.session_token,
        "album_id" => access_session.album_id
      },
      expires: access_session.expires_at,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }

    # Expiration info for the JavaScript countdown.
    cookies[:guest_session_expires_at] = {
      value: access_session.expires_at.to_i.to_s,
      expires: access_session.expires_at,
      httponly: false # Allow JavaScript access
    }

    access_session
  end

  def set_guest_session_info
    return unless @current_guest_session

    @session_expires_in_seconds = @current_guest_session.expires_in_seconds
    @session_expires_in_minutes = @current_guest_session.expires_in_minutes
  end
end
