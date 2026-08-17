class PhotosController < ApplicationController
  PER_PAGE = 60

  before_action :authenticate_user!
  before_action :set_photo, only: [ :show, :edit, :update, :destroy, :processing_status, :retry_processing ]
  before_action :ensure_viewable, only: [ :show, :processing_status ]
  before_action :ensure_owner, only: [ :edit, :update, :destroy, :retry_processing ]

  def index
    begin
      @scope_user = resolve_scope_user
      return if performed?

      @photos = @scope_user ? @scope_user.photos : family_scoped_photos

      # Apply search filters
      @photos = apply_search_filters(@photos)
      @total_count = @photos.count
      @page = [ params[:page].to_i, 1 ].max
      @photos = @photos.recent.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
      @total_pages = (@total_count / PER_PAGE.to_f).ceil
    rescue ActiveRecord::RecordNotFound
      redirect_to photos_path, alert: "User not found."
    end
  end

  def show
  end

  def processing_status
    render json: {
      state: @photo.processing_state,
      settled: @photo.processing_settled?,
      failed: @photo.processing_failed?,
      retryable: @photo.retryable?,
      error: @photo.processing_error,
      background_processing_complete: @photo.background_processing_complete?,
      all_variants_ready: @photo.all_variants_ready?,
      processing_completed_at: @photo.processing_completed_at
    }
  end

  def retry_processing
    if @photo.retryable?
      @photo.retry_processing!
      redirect_to @photo, notice: "Retrying image processing."
    else
      redirect_to @photo, alert: "This photo can't be retried right now."
    end
  end

  def new
    @photo = current_user.photos.build
  end

  def edit
  end
  def create
    @photo = current_user.photos.build(photo_params)

    if @photo.save
      # Add to album if specified
      if params[:photo][:album_id].present?
        album = current_user.albums.find_by(id: params[:photo][:album_id])
        album&.add_photo(@photo)
      end

      respond_to do |format|
        format.html { redirect_to @photo, notice: "Photo was successfully uploaded!" }
        format.json { render json: { id: @photo.id, status: "success", url: photo_path(@photo) } }
      end
    else
      handle_validation_errors(@photo)
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @photo.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end


  def update
    if @photo.update(photo_params)
      redirect_to @photo, notice: "Photo was successfully updated!"
    else
      handle_validation_errors(@photo)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      album_count = @photo.albums.count
      album_names = @photo.albums.limit(3).pluck(:name)

      @photo.destroy!

      if album_count > 0
        album_text = album_count == 1 ? "album" : "albums"
        if album_count <= 3
          notice_text = "Photo was successfully deleted and removed from #{album_count} #{album_text}: #{album_names.join(', ')}."
        else
          notice_text = "Photo was successfully deleted and removed from #{album_count} #{album_text}."
        end
        redirect_to photos_path, notice: notice_text
      else
        redirect_to photos_path, notice: "Photo was successfully deleted!"
      end
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error "Failed to delete photo #{@photo.id}: #{e.message}"
      redirect_to @photo, alert: "Unable to delete photo. Please try again."
    end
  end

  private

  def set_photo
    @photo = Photo.find(params[:id])
  end

  def ensure_owner
    redirect_to photos_path, alert: "You can only manage your own photos." unless @photo.user == current_user
  end

  def ensure_viewable
    return if @photo.viewable_by?(current_user)

    respond_to do |format|
      format.html { redirect_to photos_path, alert: "You do not have access to that photo." }
      format.json { render json: { error: "forbidden" }, status: :forbidden }
    end
  end

  # ?user_id= may only target someone in your own family. Anything else is an
  # attempt to enumerate a stranger's library.
  def resolve_scope_user
    return nil if params[:user_id].blank?

    target = User.find(params[:user_id])
    return target if target == current_user
    return target if current_user.family.present? && target.family == current_user.family

    redirect_to photos_path, alert: "You do not have access to that photo library."
    nil
  end

  # Default library view: your own photos, plus anything your family has put
  # into an album you can actually see.
  def family_scoped_photos
    return current_user.photos unless params[:family_id].present? && current_user.family.present?
    return current_user.photos unless params[:family_id].to_s == current_user.family.id.to_s

    Photo.where(user_id: current_user.family.users.select(:id))
         .where(
           "photos.user_id = :uid OR EXISTS (
              SELECT 1 FROM album_photos
              INNER JOIN albums ON albums.id = album_photos.album_id
              WHERE album_photos.photo_id = photos.id AND albums.privacy = 'family'
            )",
           uid: current_user.id
         )
         .distinct
  end

  def photo_params
    params.require(:photo).permit(:title, :description, :location, :taken_at, :image)
  end

  def apply_search_filters(photos)
    # Search by title and description
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      photos = photos.where(
        "title ILIKE ? OR description ILIKE ? OR location ILIKE ?",
        search_term, search_term, search_term
      )
    end

    # Filter by location
    photos = photos.where("location ILIKE ?", "%#{params[:location]}%") if params[:location].present?

    # Filter by date range
    if params[:date_from].present?
      photos = photos.where("taken_at >= ?", params[:date_from])
    end

    if params[:date_to].present?
      photos = photos.where("taken_at <= ?", params[:date_to])
    end

    # Filter by album
    if params[:album_id].present?
      photos = photos.joins(:albums).where(albums: { id: params[:album_id] })
    end

    photos
  end
end
