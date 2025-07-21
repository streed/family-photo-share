class ExternalAlbumsController < ApplicationController
  skip_before_action :authenticate_user!
  layout 'external'
  before_action :set_album_by_token, only: [:show, :authenticate, :password_form]
  before_action :check_external_access_enabled, only: [:show, :authenticate, :password_form]
  before_action :verify_external_access, only: [:show]
  
  # Rate limiting for password attempts
  before_action :check_rate_limit, only: [:authenticate]
  
  def show
    @photos = @album.ordered_photos.includes(:user)
    @is_external_access = true
  end
  
  def authenticate
    if @album.accessible_externally_with_password?(params[:password])
      # Create access session
      access_session = @album.create_access_session(request.remote_ip)
      
      # Set session cookie
      cookies.signed[:album_access] = {
        value: {
          'token' => access_session.session_token,
          'album_id' => @album.id
        },
        expires: 1.day.from_now,
        httponly: true,
        secure: Rails.env.production?
      }
      
      redirect_to external_album_path(@album.sharing_token), notice: 'Access granted!'
    else
      # Track failed attempt
      track_failed_attempt
      
      flash.now[:alert] = 'Incorrect password. Please try again.'
      render :password_form
    end
  end
  
  def password_form
    # This action renders the password entry form
  end
  
  private
  
  def set_album_by_token
    @album = Album.find_by(sharing_token: params[:token])
    
    unless @album
      render_not_found
      return false
    end
  end
  
  def check_external_access_enabled
    unless @album.allow_external_access?
      render_not_found
      return false
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
    album_id = session_data['album_id'] || session_data[:album_id]
    token = session_data['token'] || session_data[:token]
    
    return false unless album_id == @album.id
    
    # Check if we have a valid session in the database
    access_session = @album.album_access_sessions.find_by(session_token: token)
    return false unless access_session
    return false if access_session.expired?
    
    # Touch the access to update last accessed time
    access_session.touch_access!
    true
  end
  
  def check_rate_limit
    cache_key = "album_password_attempts:#{request.remote_ip}:#{@album.id}"
    attempts = Rails.cache.read(cache_key) || 0
    
    if attempts >= 5
      render json: { error: 'Too many attempts. Please try again later.' }, 
             status: :too_many_requests
      return false
    end
  end
  
  def track_failed_attempt
    cache_key = "album_password_attempts:#{request.remote_ip}:#{@album.id}"
    attempts = Rails.cache.read(cache_key) || 0
    Rails.cache.write(cache_key, attempts + 1, expires_in: 1.hour)
  end
  
  def render_not_found
    render file: Rails.root.join('public', '404.html'), 
           status: :not_found, 
           layout: false
  end
  
end