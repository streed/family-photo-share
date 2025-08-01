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
  end

  def create
    @bulk_upload = current_user.bulk_uploads.build(bulk_upload_params.except(:titles, :descriptions))

    if @bulk_upload.save
      # Store individual photo metadata temporarily
      store_photo_metadata(@bulk_upload)

      # Process the upload in the background
      BulkUploadProcessingJob.perform_async(@bulk_upload.id)
      redirect_to bulk_upload_path(@bulk_upload), notice: "Your photos are being processed. You will be notified when they are ready."
    else
      render :new
    end
  end



  private

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
