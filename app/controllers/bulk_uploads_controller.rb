class BulkUploadsController < ApplicationController
  before_action :authenticate_user!

  def index
    @bulk_uploads = current_user.bulk_uploads.order(created_at: :desc)
  end
  def show
    @bulk_upload = current_user.bulk_uploads.find(params[:id])
    @processed_photos = @bulk_upload.photos.includes(:user, image_attachment: :blob)
  end
  def new
    @bulk_upload = BulkUpload.new
    load_album_choices
  end

  def create
    attrs = bulk_upload_params.except(:titles, :descriptions)
    @bulk_upload = current_user.bulk_uploads.build(attrs)

    # album_id arrives from the form, so it has to be checked against the
    # uploader — otherwise photos can be pushed into anyone's album by id.
    # Albums a relative has opened up for contributions count as well.
    if attrs[:album_id].present? && !Album.addable_by(current_user).exists?(id: attrs[:album_id])
      @bulk_upload.errors.add(:album_id, "is not an album you can add photos to")
      handle_validation_errors(@bulk_upload)
      load_album_choices
      return render :new, status: :unprocessable_content
    end

    if @bulk_upload.save
      # Store individual photo metadata temporarily
      store_photo_metadata(@bulk_upload)

      # Process the upload in the background
      BulkUploadProcessingJob.perform_async(@bulk_upload.id)
      redirect_to bulk_upload_path(@bulk_upload), notice: "Your photos are being processed. You will be notified when they are ready."
    else
      load_album_choices
      render :new
    end
  end



  private

  # Where these photos can land: your own albums, plus any family album a
  # relative has opened up for contributions.
  def load_album_choices
    @own_albums = current_user.albums.recent.to_a
    @shared_albums = Album.addable_by(current_user)
                          .where.not(user_id: current_user.id)
                          .includes(:user)
                          .recent
                          .to_a
  end

  def bulk_upload_params
    params.require(:bulk_upload).permit(:album_id, images: [], titles: [], descriptions: [])
  end

  def store_photo_metadata(bulk_upload)
    titles = params.dig(:bulk_upload, :titles) || []
    descriptions = params.dig(:bulk_upload, :descriptions) || []

    # Store metadata as JSON in the bulk upload record for processing
    metadata = bulk_upload.images.each_with_index.map do |image, index|
      {
        filename: image.filename.to_s,
        title: titles[index].presence,
        description: descriptions[index].presence
      }
    end

    bulk_upload.update!(metadata: metadata.to_json)
  end
end
