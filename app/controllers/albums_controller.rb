class AlbumsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_album, only: [:show, :edit, :update, :destroy, :add_photo, :remove_photo, :set_cover]
  before_action :ensure_access, only: [:show]
  before_action :ensure_owner, only: [:edit, :update, :destroy, :add_photo, :remove_photo, :set_cover]

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

  def create
    @album = current_user.albums.build(album_params)
    
    if @album.save
      redirect_to @album, notice: 'Album was successfully created!'
    else
      handle_validation_errors(@album)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @album.update(album_params)
      redirect_to @album, notice: 'Album was successfully updated!'
    else
      handle_validation_errors(@album)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      @album.destroy!
      redirect_to albums_path, notice: 'Album was successfully deleted!'
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to @album, alert: 'Unable to delete album. Please try again.'
    end
  end

  def add_photo
    begin
      photo = Photo.find(params[:photo_id])
      
      if photo.user != current_user
        redirect_to @album, alert: 'You can only add your own photos to albums.'
        return
      end
      
      if @album.add_photo(photo)
        redirect_to @album, notice: 'Photo added to album!'
      else
        redirect_to @album, alert: 'Photo is already in this album.'
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to @album, alert: 'Photo not found.'
    end
  end

  def remove_photo
    begin
      photo = Photo.find(params[:photo_id])
      
      if @album.remove_photo(photo)
        redirect_to @album, notice: 'Photo removed from album!'
      else
        redirect_to @album, alert: 'Unable to remove photo from album.'
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to @album, alert: 'Photo not found.'
    end
  end

  def set_cover
    begin
      photo = Photo.find(params[:photo_id])
      
      if @album.set_cover_photo(photo)
        redirect_to @album, notice: 'Cover photo updated!'
      else
        redirect_to @album, alert: 'Unable to set cover photo.'
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to @album, alert: 'Photo not found.'
    end
  end

  private

  def set_album
    @album = Album.find(params[:id])
  end

  def ensure_access
    redirect_to albums_path, alert: 'You do not have access to this album.' unless @album.accessible_by?(current_user)
  end

  def ensure_owner
    redirect_to @album, alert: 'You can only manage your own albums.' unless @album.editable_by?(current_user)
  end

  def album_params
    params.require(:album).permit(:name, :description, :privacy, :allow_external_access, :password)
  end
end
