class AlbumsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_album, only: [ :show, :edit, :update, :destroy, :add_photo, :remove_photo, :set_cover, :view_events, :guest_sessions, :revoke_guest_session, :revoke_all_guest_sessions ]
  before_action :ensure_access, only: [ :show ]
  before_action :ensure_owner, only: [ :edit, :update, :destroy, :add_photo, :remove_photo, :set_cover, :view_events, :guest_sessions, :revoke_guest_session, :revoke_all_guest_sessions ]

  def index
    @albums = current_user.albums.recent.includes(:cover_photo)
    @albums = @albums.by_privacy(params[:privacy]) if params[:privacy].present?
  end

  def show
    @photos = @album.ordered_photos.includes(:user)
    @user_photos = current_user.photos.where.not(id: @album.photo_ids) if @album.editable_by?(current_user)
  end

  def new
    @album = current_user.albums.build
  end

  def edit
  end
  def create
    @album = current_user.albums.build(album_params)

    if @album.save
      redirect_to @album, notice: "Album was successfully created!"
    else
      handle_validation_errors(@album)
      render :new, status: :unprocessable_entity
    end
  end


  def update
    if @album.update(album_params)
      redirect_to @album, notice: "Album was successfully updated!"
    else
      handle_validation_errors(@album)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      @album.destroy!
      redirect_to albums_path, notice: "Album was successfully deleted!"
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to @album, alert: "Unable to delete album. Please try again."
    end
  end

  def add_photo
    begin
      photo = Photo.find(params[:photo_id])

      if photo.user != current_user
        redirect_to @album, alert: "You can only add your own photos to albums."
        return
      end

      if @album.add_photo(photo)
        redirect_to @album, notice: "Photo added to album!"
      else
        redirect_to @album, alert: "Photo is already in this album."
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to @album, alert: "Photo not found."
    end
  end

  def remove_photo
    begin
      photo = Photo.find(params[:photo_id])

      if @album.remove_photo(photo)
        respond_to do |format|
          format.html { redirect_to album_path(@album), notice: "Photo removed from album!" }
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace("photo_#{photo.id}", "")
          }
        end
      else
        Rails.logger.warn "Failed to remove photo #{photo.id} from album #{@album.id}"
        respond_to do |format|
          format.html { redirect_to @album, alert: "Unable to remove photo from album." }
          format.turbo_stream { redirect_to @album, alert: "Unable to remove photo from album." }
        end
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Photo not found when trying to remove from album: #{e.message}"
      respond_to do |format|
        format.html { redirect_to @album, alert: "Photo not found." }
        format.turbo_stream { redirect_to @album, alert: "Photo not found." }
      end
    rescue => e
      Rails.logger.error "Unexpected error removing photo from album: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { redirect_to @album, alert: "An error occurred while removing the photo." }
        format.turbo_stream { redirect_to @album, alert: "An error occurred while removing the photo." }
      end
    end
  end

  def set_cover
    begin
      photo = Photo.find(params[:photo_id])

      if @album.set_cover_photo(photo)
        redirect_to @album, notice: "Cover photo updated!"
      else
        redirect_to @album, alert: "Unable to set cover photo."
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to @album, alert: "Photo not found."
    end
  end

  def view_events
    @events = @album.album_view_events.recent
                    .includes(:photo)
                    .order(occurred_at: :desc)
                    .limit(100)

    # Get base query for statistics
    recent_events = @album.album_view_events.recent

    # Group events by type for summary
    @event_counts = recent_events.group(:event_type).count
    @unique_visitors = recent_events.distinct.count(:ip_address)
    @total_photo_views = recent_events.by_type("photo_view").count
    @password_attempts = recent_events.where(event_type: [ "password_entry", "password_attempt_failed" ]).count
  end

  def guest_sessions
    # Only show guest sessions page if external access is enabled
    unless @album.allow_external_access?
      redirect_to @album, alert: "Guest access is not enabled for this album."
      return
    end

    @active_sessions = @album.album_access_sessions.active.recent
    @expired_sessions = @album.album_access_sessions.expired.recent.limit(20)
    @total_sessions_count = @album.album_access_sessions.count
  end

  def revoke_guest_session
    session = @album.album_access_sessions.find_by(session_token: params[:session_token])

    if session
      was_active = !session.expired?
      session.destroy

      if was_active
        redirect_to guest_sessions_album_path(@album), notice: "Guest session revoked successfully. The guest user has been logged out."
      else
        redirect_to guest_sessions_album_path(@album), notice: "Expired session removed from records."
      end
    else
      redirect_to guest_sessions_album_path(@album), alert: "Session not found or already removed."
    end
  end

  def revoke_all_guest_sessions
    count = @album.album_access_sessions.active.count

    if count == 0
      redirect_to guest_sessions_album_path(@album), alert: "No active guest sessions to revoke."
      return
    end

    @album.revoke_all_access_sessions
    redirect_to guest_sessions_album_path(@album), notice: "Success! #{pluralize(count, 'active guest session')} revoked. All guest users have been logged out."
  end

  private

  def set_album
    @album = Album.find(params[:id])
  end

  def ensure_access
    redirect_to albums_path, alert: "You do not have access to this album." unless @album.accessible_by?(current_user)
  end

  def ensure_owner
    redirect_to @album, alert: "You can only manage your own albums." unless @album.editable_by?(current_user)
  end

  def album_params
    params.require(:album).permit(:name, :description, :privacy, :allow_external_access, :password)
  end
end
