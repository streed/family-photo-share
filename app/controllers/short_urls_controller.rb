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
    
    # Track access
    @short_url.track_access!
    
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
          redirect_to new_user_session_path, alert: 'Please sign in to view this photo.'
        end
        return
      end
    end
    
    # Serve the image content directly
    serve_image_content
  end
  
  private
  
  def serve_image_content
    photo = @short_url.resource
    return render_not_found unless photo&.image&.attached?
    
    # Get the appropriate variant based on the short URL
    variant_attachment = get_variant_attachment(photo)
    return render_not_found unless variant_attachment
    
    # Set caching headers
    expires_in 1.hour, public: true
    
    # Set content type
    response.headers['Content-Type'] = variant_attachment.content_type
    response.headers['Content-Disposition'] = 'inline'
    
    # Set additional headers for better caching and security
    response.headers['Cache-Control'] = 'public, max-age=3600'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    
    # Try to serve the variant, but fallback to original if variant doesn't exist
    begin
      # For better performance with large files, use streaming if blob service allows it
      if variant_attachment.service.respond_to?(:path_for)
        # For disk storage, we can send the file directly
        file_path = variant_attachment.service.send(:path_for, variant_attachment.key)
        if File.exist?(file_path)
          send_file file_path,
                    type: variant_attachment.content_type,
                    disposition: 'inline',
                    filename: "#{photo.title.parameterize}.#{get_file_extension(variant_attachment.content_type)}"
          return
        end
      end
      
      # Fallback to downloading and sending data
      send_data variant_attachment.download, 
                type: variant_attachment.content_type,
                disposition: 'inline',
                filename: "#{photo.title.parameterize}.#{get_file_extension(variant_attachment.content_type)}"
    rescue ActiveStorage::FileNotFoundError => e
      Rails.logger.warn "Variant not found for ShortUrl #{@short_url.id}, falling back to original image: #{e.message}"
      # Fallback to original image
      original_image = photo.image
      send_data original_image.download,
                type: original_image.content_type,
                disposition: 'inline',
                filename: "#{photo.title.parameterize}.#{get_file_extension(original_image.content_type)}"
    end
  rescue => e
    Rails.logger.error "Error serving image content for ShortUrl #{@short_url.id}: #{e.message}"
    render_not_found
  end
  
  def get_variant_attachment(photo)
    case @short_url.variant
    when 'thumbnail'
      photo.thumbnail
    when 'small'
      photo.small
    when 'medium'
      photo.medium
    when 'large'
      photo.large
    when 'xl'
      photo.xl
    when 'original'
      photo.image
    else
      photo.image
    end
  end
  
  def get_file_extension(content_type)
    case content_type
    when 'image/jpeg'
      'jpg'
    when 'image/png'
      'png'
    when 'image/gif'
      'gif'
    when 'image/webp'
      'webp'
    else
      'jpg'
    end
  end
  
  def photo_belongs_to_external_album?
    return false unless @short_url.resource_type == 'Photo'
    
    photo = @short_url.resource
    return false unless photo
    
    # Check if photo belongs to any album with external access
    photo.albums.any?(&:allow_external_access?)
  end
  
  
  def valid_external_album_session?
    return false unless cookies.signed[:album_access]
    
    session_data = cookies.signed[:album_access]
    return false unless session_data.is_a?(Hash)
    
    # Get album ID from session
    album_id = session_data['album_id'] || session_data[:album_id]
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
    token = session_data['token'] || session_data[:token]
    return false unless token
    
    access_session = album.album_access_sessions.find_by(session_token: token)
    return false unless access_session
    return false if access_session.expired?
    
    true
  end
  
  def redirect_to_album_password
    photo = @short_url.resource
    album = photo.albums.find(&:allow_external_access?)
    
    if album&.sharing_token
      redirect_to external_album_password_path(album.sharing_token)
    else
      render_forbidden
    end
  end
  
  def user_can_access_photo?
    photo = @short_url.resource
    return false unless photo
    
    # Photo owner can always access
    return true if photo.user == current_user
    
    # Check if user is in any family that has access to photo's albums
    photo.albums.any? do |album|
      album.user == current_user || 
      (album.user.family && album.user.family.users.include?(current_user))
    end
  end
  
  def render_not_found
    render file: Rails.root.join('public', '404.html'), 
           status: :not_found, 
           layout: false
  end
  
  def render_expired
    render plain: 'This link has expired.', status: :gone
  end
  
  def render_forbidden
    render file: Rails.root.join('public', '403.html'), 
           status: :forbidden, 
           layout: false
  end
  
end