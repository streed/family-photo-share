class AlbumsController < ApplicationController
  # An album grid and the picker below it are both unbounded sets. Rendering
  # every tile of a few-hundred-photo album is a slow response and a burst of
  # image requests; these cap each at a screenful or two.
  PHOTOS_PER_PAGE = 24
  PICKER_PER_PAGE = 20

  before_action :authenticate_user!
  before_action :set_album, only: [ :show, :edit, :update, :destroy, :add_photo, :remove_photo, :set_cover, :view_events, :guest_sessions, :revoke_guest_session, :revoke_all_guest_sessions ]
  before_action :ensure_access, only: [ :show ]
  before_action :ensure_owner, only: [ :edit, :update, :destroy, :set_cover, :view_events, :guest_sessions, :revoke_guest_session, :revoke_all_guest_sessions ]
  # Adding and removing photos is no longer owner-only: a family album the owner
  # has opened up can be added to by any member of that family.
  before_action :ensure_can_add_photos, only: [ :add_photo, :remove_photo ]

  def index
    @albums = current_user.albums.recent.includes(cover_photo: { image_attachment: :blob })
    @albums = @albums.by_privacy(params[:privacy]) if params[:privacy].present?
    @albums = @albums.to_a

    # Albums a family member has shared with you. Without this, album sharing has
    # no recipient-side surface at all.
    @family_albums = if current_user.family.present?
      Album.family_albums
           .where(user_id: current_user.family.users.select(:id))
           .where.not(user_id: current_user.id)
           .recent
           .includes(:user, cover_photo: { image_attachment: :blob })
           .to_a
    else
      []
    end

    ShortUrl.warm_for_photos(
      (@albums + @family_albums).filter_map(&:cover_photo),
      [ :medium ]
    )
  end

  def show
    load_permissions
    load_album_photos
    load_picker_photos
    warm_short_urls
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
      render :new, status: :unprocessable_content
    end
  end


  def update
    if @album.update(album_params)
      redirect_to @album, notice: "Album was successfully updated!"
    else
      handle_validation_errors(@album)
      render :edit, status: :unprocessable_content
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
      photo = current_user.photos.find(params[:photo_id])

      if @album.add_photo(photo)
        respond_to do |format|
          format.html { redirect_to @album, notice: "Photo added to album!" }
          format.turbo_stream do
            load_album_photo_state
            render :update_photos, locals: {
              added_photo: photo,
              notice: "Added to album."
            }
          end
        end
      else
        redirect_to @album, alert: "Photo is already in this album."
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to @album, alert: "Photo not found."
    end
  end

  def remove_photo
    begin
      photo = @album.photos.find(params[:photo_id])

      unless @album.photo_removable_by?(photo, current_user)
        return redirect_to @album, alert: "You can only remove photos you added to this album."
      end

      if @album.remove_photo(photo)
        respond_to do |format|
          format.html { redirect_to album_path(@album), notice: "Photo removed from album!" }
          format.turbo_stream do
            load_album_photo_state
            render :update_photos, locals: {
              removed_photo: photo,
              notice: "Removed from album."
            }
          end
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
      photo = @album.photos.find(params[:photo_id])

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
    # Just the photo: the thumbnails in this table render through warmed short
    # URLs, which never touch the attachment record.
    @events = @album.album_view_events.recent
                    .includes(:photo)
                    .order(occurred_at: :desc)
                    .limit(100)
                    .to_a

    ShortUrl.warm_for_photos(@events.filter_map(&:photo), [ :thumbnail ])

    # Get base query for statistics
    recent_events = @album.album_view_events.recent

    # Group events by type for summary
    @event_counts = recent_events.group(:event_type).count
    @unique_visitors = recent_events.distinct.count(:ip_address)
    @total_photo_views = recent_events.by_type("photo_view").count
    @password_attempts = recent_events.where(event_type: [ "password_entry", "password_attempt_failed" ]).count

    # One query for every address on the page, instead of one per row.
    @ip_locations = IpLocation.lookup_map(@events.map(&:ip_address))

    # Anything not resolved yet (or never seen before) gets picked up in the
    # background, so the table fills in on the next visit.
    @events.map(&:ip_address).compact.uniq.each { |ip| IpLocation.resolve_later(ip) }
  end

  def guest_sessions
    # Only show guest sessions page if external access is enabled
    unless @album.allow_external_access?
      redirect_to @album, alert: "Guest access is not enabled for this album."
      return
    end

    @active_sessions = @album.album_access_sessions.active.recent.to_a
    @expired_sessions = @album.album_access_sessions.expired.recent.limit(20).to_a
    @total_sessions_count = @album.album_access_sessions.count

    @ip_locations = IpLocation.lookup_map((@active_sessions + @expired_sessions).map(&:ip_address))
    (@active_sessions + @expired_sessions).map(&:ip_address).compact.uniq.each do |ip|
      IpLocation.resolve_later(ip)
    end
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
    # pluralize is a view helper, not a controller method — calling it bare here
    # raised NoMethodError and 500'd the whole revoke action.
    revoked = view_context.pluralize(count, "active guest session")
    redirect_to guest_sessions_album_path(@album), notice: "Success! #{revoked} revoked. All guest users have been logged out."
  end

  private

  def set_album
    @album = Album.find(params[:id])
  end

  # Everything the album page shows about its photos, reloaded after a change so
  # a turbo_stream response can keep the grid, the count and the picker in sync
  # instead of updating one tile and leaving the rest stale.
  def load_album_photo_state
    @album.reload
    load_permissions
    load_album_photos
    load_picker_photos
    warm_short_urls
  end

  # One page of the album grid, newest addition first.
  def load_album_photos
    @sort = @album.sort_order_for(params[:sort])
    @photo_total = @album.photo_count
    @total_pages = [ (@photo_total / PHOTOS_PER_PAGE.to_f).ceil, 1 ].max
    @page = page_param(:page, @total_pages)

    @photos = @album.ordered_photos(sort: @sort)
                    .includes(:user, image_attachment: :blob)
                    .offset((@page - 1) * PHOTOS_PER_PAGE)
                    .limit(PHOTOS_PER_PAGE)
                    .to_a
  end

  # One page of the picker: your own photos that aren't in this album yet, most
  # recently uploaded first — the ones you are nearly always reaching for.
  def load_picker_photos
    return unless @can_add_photos

    addable = current_user.photos.where.not(id: @album.photo_ids).recent
    @addable_photo_count = addable.count
    @picker_total_pages = [ (@addable_photo_count / PICKER_PER_PAGE.to_f).ceil, 1 ].max
    @picker_page = page_param(:picker_page, @picker_total_pages)

    @pickable_photos = addable.offset((@picker_page - 1) * PICKER_PER_PAGE)
                              .limit(PICKER_PER_PAGE)
                              .includes(image_attachment: :blob)
                              .to_a
  end

  # Missing, zero and "'; DROP TABLE" all land on page 1; anything past the end
  # lands on the last page, so a stale link shows photos rather than a blank grid.
  def page_param(key, total_pages)
    params[key].to_i.clamp(1, total_pages)
  end

  # Resolve every short URL the page needs up front, instead of one query (and
  # sometimes an INSERT) per photo per variant while rendering.
  def warm_short_urls
    ShortUrl.warm_for_photos(@photos, [ :thumbnail, :large ])
    ShortUrl.warm_for_photos(@pickable_photos, [ :thumbnail ]) if @pickable_photos.present?
    ShortUrl.warm_for_photos([ @album.cover_photo ].compact, [ :large ])
  end

  def ensure_access
    redirect_to albums_path, alert: "You do not have access to this album." unless @album.accessible_by?(current_user)
  end

  def ensure_owner
    redirect_to @album, alert: "You can only manage your own albums." unless @album.editable_by?(current_user)
  end

  def ensure_can_add_photos
    return if @album.photos_addable_by?(current_user)

    redirect_to albums_path, alert: "You can't add photos to this album."
  end

  # Resolved once per request and handed to the views. Both #contributable_by?
  # and the per-tile remove button need the owner's family, and asking per tile
  # would be one query per photo in the grid.
  def load_permissions
    @editable = @album.editable_by?(current_user)
    @contributor = @album.contributable_by?(current_user)
    @can_add_photos = @editable || @contributor
  end

  def album_params
    params.require(:album).permit(:name, :description, :privacy, :allow_external_access,
                                  :allow_contributions, :password)
  end
end
