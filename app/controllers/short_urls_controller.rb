class ShortUrlsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @short_url = ShortUrl.find_by(token: params[:token])

    unless @short_url
      render_not_found
      return
    end

    # Check if expired
    if @short_url.expired?
      render_expired
      return
    end

    # Check if the resource is available
    unless @short_url.available?
      render_not_found
      return
    end

    # Authentication and access control
    if user_signed_in?
      # Authenticated user - verify they can access this photo
      unless user_can_access_photo?
        render_forbidden
        return
      end
    else
      # Not authenticated - check for external album access
      if photo_belongs_to_external_album? && valid_external_album_session?
        # Valid external album session - allow access
      else
        # No valid access - redirect to appropriate login/password page
        if photo_belongs_to_external_album?
          redirect_to_album_password
        else
          redirect_to new_user_session_path, alert: "Please sign in to view this photo."
        end
        return
      end
    end

    # Count the access only once the viewer is actually allowed to see it. This
    # used to run before the authorization checks, so the counter also tallied
    # denied requests and every sign-in redirect.
    @short_url.track_access!

    # Serve the image content directly
    serve_image_content
  end

  private

  def serve_image_content
    photo = @short_url.resource
    return render_not_found unless photo&.image&.attached?

    result = PhotoVariantStreamer.call(photo: photo, variant: @short_url.variant)
    return render_not_found unless result

    # These bytes are authorized per-viewer, so they must never land in a shared
    # proxy or CDN cache. The browser may still hold onto them privately.
    expires_in 1.hour, public: false
    response.headers["Cache-Control"] = "private, max-age=3600"
    response.headers["X-Content-Type-Options"] = "nosniff"

    if result.disk?
      send_file result.path, type: result.content_type, disposition: "inline", filename: result.filename
    else
      send_data result.data, type: result.content_type, disposition: "inline", filename: result.filename
    end
  rescue ActiveStorage::FileNotFoundError, Errno::ENOENT => e
    # The blob really is gone — a 404 is the honest answer.
    Rails.logger.error "Missing file for ShortUrl #{@short_url.id}: #{e.class}: #{e.message}"
    render_not_found
  rescue => e
    # Anything else is a bug. A blanket rescue here turned NoMethodError into a
    # 404, which is how unprocessed variants silently rendered as broken tiles
    # for months with nothing but a 404 in the logs to show for it.
    Rails.logger.error "Error serving image content for ShortUrl #{@short_url.id}: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace&.first(10)&.join("\n")
    raise
  end

  def photo_belongs_to_external_album?
    return false unless @short_url.resource_type == "Photo"

    photo = @short_url.resource
    return false unless photo

    photo.albums.exists?(allow_external_access: true)
  end


  def valid_external_album_session?
    return false unless cookies.signed[:album_access]

    session_data = cookies.signed[:album_access]
    return false unless session_data.is_a?(Hash)

    # Get album ID from session
    album_id = session_data["album_id"] || session_data[:album_id]
    return false unless album_id

    # Check if photo belongs to this album
    photo = @short_url.resource
    return false unless photo

    album = Album.find_by(id: album_id)
    return false unless album

    # Verify photo is in this album and session is valid
    album.photos.include?(photo) && album_session_valid?(album, session_data)
  end

  def album_session_valid?(album, session_data)
    token = session_data["token"] || session_data[:token]
    return false unless token

    access_session = album.album_access_sessions.find_by(session_token: token)
    return false unless access_session
    return false if access_session.expired?

    true
  end

  # Only ever point a visitor back at the album they already arrived through.
  # Picking an arbitrary shared album containing this photo would hand out a
  # sharing_token the visitor was never given.
  def redirect_to_album_password
    album = album_from_access_cookie

    if album&.allow_external_access? && album.sharing_token.present? && album.photos.exists?(@short_url.resource_id)
      redirect_to external_album_password_path(album.sharing_token)
    else
      render_forbidden
    end
  end

  def album_from_access_cookie
    session_data = cookies.signed[:album_access]
    return nil unless session_data.is_a?(Hash)

    album_id = session_data["album_id"] || session_data[:album_id]
    album_id && Album.find_by(id: album_id)
  end

  def user_can_access_photo?
    photo = @short_url.resource
    return false unless photo

    # Owning the photo is enough; otherwise it has to reach the viewer through
    # an album they can see. Sharing a family with the owner is NOT sufficient —
    # that would expose photos sitting in the owner's private albums.
    photo.viewable_by?(current_user)
  end

  def render_not_found
    render file: Rails.public_path.join("404.html"),
           status: :not_found,
           layout: false
  end

  def render_expired
    render plain: "This link has expired.", status: :gone
  end

  def render_forbidden
    render file: Rails.public_path.join("403.html"),
           status: :forbidden,
           layout: false
  end
end
