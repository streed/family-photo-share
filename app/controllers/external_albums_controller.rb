class ExternalAlbumsController < ApplicationController
  include GuestSessionTracking

  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [ :track_photo_view ]
  layout "external"
  before_action :set_album_by_token, only: [ :show, :authenticate, :password_form, :track_photo_view ]
  before_action :check_external_access_enabled, only: [ :show, :authenticate, :password_form, :track_photo_view ]
  before_action :verify_external_access, only: [ :show, :track_photo_view ]
  before_action :set_guest_session_info, only: [ :show ]

  # Rate limiting for password attempts
  before_action :check_rate_limit, only: [ :authenticate ]

  def show
    @photos = @album.ordered_photos.includes(:user)
    @is_external_access = true
  end

  def authenticate
    # Check rate limiting first (skip in development)
    if !Rails.env.development?
      attempts = get_failed_attempts

      if attempts >= 5
        remaining_time = rate_limit_remaining_time
        flash.now[:alert] = "Too many incorrect password attempts. Please try again in #{remaining_time} #{'minute'.pluralize(remaining_time)}."
        render :password_form and return
      end
    end

    if @album.accessible_externally_with_password?(params[:password])
      # Create access session
      access_session = @album.create_access_session(request.remote_ip)

      # Track successful password entry
      AlbumViewEvent.track_password_entry(@album, request, access_session.session_token)

      # Set session cookie - expires in 10 minutes from creation
      cookies.signed[:album_access] = {
        value: {
          "token" => access_session.session_token,
          "album_id" => @album.id
        },
        expires: access_session.expires_at,
        httponly: true,
        secure: Rails.env.production?
      }

      # Set expiration info for JavaScript countdown
      cookies[:guest_session_expires_at] = {
        value: access_session.expires_at.to_i.to_s,
        expires: access_session.expires_at,
        httponly: false # Allow JavaScript access
      }

      # Clear failed attempts
      clear_failed_attempts unless Rails.env.development?

      redirect_to external_album_path(@album.sharing_token), notice: "Welcome! You now have access to view this album. Your session will expire in 10 minutes."
    else
      # Track failed attempt
      track_failed_attempt unless Rails.env.development?
      AlbumViewEvent.track_failed_password_attempt(@album, request)

      # Add error message exactly like sessions controller
      if Rails.env.development?
        flash.now[:alert] = "Incorrect password. Please try again."
      else
        attempts = get_failed_attempts
        attempts_left = 5 - attempts

        if attempts_left == 1
          flash.now[:alert] = "Incorrect password. Warning: You have 1 more attempt before access is temporarily blocked."
        elsif attempts_left > 0
          flash.now[:alert] = "Incorrect password. You have #{attempts_left} attempts remaining."
        else
          flash.now[:alert] = "Incorrect password. This was your last attempt - access is now temporarily blocked."
        end
      end

      render :password_form
    end
  end

  def password_form
    # This action renders the password entry form
  end

  def track_photo_view
    photo = @album.photos.find(params[:photo_id])
    session_token = @current_guest_session&.session_token || "anonymous"

    AlbumViewEvent.track_photo_view(@album, photo, request, session_token)

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def set_album_by_token
    @album = Album.find_by(sharing_token: params[:token])

    unless @album
      render_not_found
      false
    end
  end

  def check_external_access_enabled
    unless @album.allow_external_access?
      render_not_found
      false
    end
  end

  def verify_external_access
    return if has_valid_session?
    redirect_to external_album_password_path(@album.sharing_token)
  end

  def has_valid_session?
    return false unless cookies.signed[:album_access]

    session_data = cookies.signed[:album_access]
    return false unless session_data.is_a?(Hash)

    # Check with both string and symbol keys for compatibility
    album_id = session_data["album_id"] || session_data[:album_id]
    token = session_data["token"] || session_data[:token]

    return false unless album_id == @album.id

    # Check if we have a valid session in the database
    access_session = @album.album_access_sessions.find_by(session_token: token)
    return false unless access_session

    # Store current session for activity tracking
    @current_guest_session = access_session

    # Check if session is still valid (this will also extend it if valid)
    access_session.valid_with_activity_check!
  end

  def check_rate_limit
    return true if Rails.env.development?

    cache_key = "album_password_attempts:#{request.remote_ip}:#{@album.id}"
    attempts = Rails.cache.read(cache_key) || 0

    if attempts >= 5
      render json: { error: "Too many attempts. Please try again later." },
             status: :too_many_requests
      false
    end
  end

  def track_failed_attempt
    cache_key = "album_password_attempts:#{request.remote_ip}:#{@album.id}"
    attempts = Rails.cache.read(cache_key) || 0
    Rails.cache.write(cache_key, attempts + 1, expires_in: 1.hour)
  end

  def get_failed_attempts
    cache_key = "album_password_attempts:#{request.remote_ip}:#{@album.id}"
    Rails.cache.read(cache_key) || 0
  end

  def clear_failed_attempts
    cache_key = "album_password_attempts:#{request.remote_ip}:#{@album.id}"
    Rails.cache.delete(cache_key)
  end

  def rate_limit_remaining_time
    # Since we use 1 hour expiry, calculate approximate remaining time
    # This is a simplified version - in production you might want to store the timestamp
    15 # Default to 15 minutes
  end

  def render_not_found
    render file: Rails.public_path.join("404.html"),
           status: :not_found,
           layout: false
  end
end
