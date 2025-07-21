class PhotosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_photo, only: [:show, :edit, :update, :destroy]
  before_action :ensure_owner, only: [:edit, :update, :destroy]

  def index
    begin
      @photos = if params[:user_id]
                  User.find(params[:user_id]).photos
                else
                  current_user.photos
                end
      
      # Apply search filters
      @photos = apply_search_filters(@photos)
      @photos = @photos.recent.limit(20)
    rescue ActiveRecord::RecordNotFound
      redirect_to photos_path, alert: 'User not found.'
    end
  end

  def show
    @photo = Photo.find(params[:id])
  end

  def processing_status
    @photo = Photo.find(params[:id])
    ensure_owner
    
    render json: {
      background_processing_complete: @photo.background_processing_complete?,
      all_variants_ready: @photo.all_variants_ready?,
      processing_completed_at: @photo.processing_completed_at
    }
  end

  def new
    @photo = current_user.photos.build
  end

  def create
    @photo = current_user.photos.build(photo_params)
    
    if @photo.save
      redirect_to @photo, notice: 'Photo was successfully uploaded!'
    else
      handle_validation_errors(@photo)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @photo.update(photo_params)
      redirect_to @photo, notice: 'Photo was successfully updated!'
    else
      handle_validation_errors(@photo)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      @photo.destroy!
      redirect_to photos_path, notice: 'Photo was successfully deleted!'
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to @photo, alert: 'Unable to delete photo. Please try again.'
    end
  end

  private

  def set_photo
    @photo = Photo.find(params[:id])
  end

  def ensure_owner
    redirect_to photos_path, alert: 'You can only manage your own photos.' unless @photo.user == current_user
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
