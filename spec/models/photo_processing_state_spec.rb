require 'rails_helper'

RSpec.describe "Photo image processing state", type: :model do
  let(:user) { create(:user) }

  def attached_photo
    photo = Photo.new(user: user, title: "state probe")
    photo.image.attach(
      io: Rails.root.join("spec/fixtures/files/test_image.jpg").open,
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )
    photo.save!
    photo
  end

  it "starts pending and is not settled" do
    photo = attached_photo

    expect(photo.processing_state).to eq("pending")
    expect(photo).not_to be_processing_settled
  end

  it "becomes ready when the job succeeds" do
    photo = attached_photo

    ImageProcessingJob.new.perform(photo.id)

    photo.reload
    expect(photo.processing_state).to eq("ready")
    expect(photo).to be_processing_settled
    expect(photo.processing_completed_at).to be_present
    expect(photo.processing_error).to be_nil
  end

  it "records a failure instead of leaving the photo stuck in processing" do
    photo = attached_photo
    allow_any_instance_of(ImageProcessingService)
      .to receive(:process_all_variants).and_raise(StandardError, "vips exploded")

    expect { ImageProcessingJob.new.perform(photo.id) }.to raise_error(StandardError, "vips exploded")

    photo.reload
    expect(photo.processing_state).to eq("failed")
    expect(photo.processing_error).to include("vips exploded")
    expect(photo).to be_processing_settled
    expect(photo).to be_retryable
  end

  it "stops offering a retry once attempts are exhausted" do
    photo = attached_photo
    photo.update_columns(processing_state: "failed", processing_attempts: Photo::MAX_PROCESSING_ATTEMPTS)

    expect(photo).not_to be_retryable
  end

  it "returns a retried photo to pending" do
    photo = attached_photo
    photo.update_columns(processing_state: "failed", processing_error: "boom", processing_attempts: 1)

    photo.retry_processing!

    photo.reload
    expect(photo.processing_state).to eq("pending")
    expect(photo.processing_error).to be_nil
  end

  describe "when the job queue is unreachable" do
    it "does not fail an upload whose row and blob already committed" do
      allow(ImageProcessingJob).to receive(:perform_async).and_raise(StandardError, "redis down")
      allow(ExtractPhotoMetadataJob).to receive(:perform_async).and_raise(StandardError, "redis down")

      photo = nil
      expect { photo = attached_photo }.not_to raise_error
      expect(photo).to be_persisted
      expect(photo.image).to be_attached
    end

    # Active Storage enqueues its own AnalyzeJob through ActiveJob on attach.
    # That one is not ours to rescue at the call site, and it used to raise
    # straight out of save! — returning HTTP 500 for an upload that succeeded.
    it "survives an ActiveJob enqueue failure from Active Storage itself" do
      allow(ImageProcessingJob).to receive(:perform_async)
      allow(ExtractPhotoMetadataJob).to receive(:perform_async)
      allow_any_instance_of(ActiveJob::QueueAdapters::TestAdapter)
        .to receive(:enqueue).and_raise(Errno::ECONNREFUSED)

      photo = nil
      expect { photo = attached_photo }.not_to raise_error
      expect(photo).to be_persisted
    end
  end

  describe "variant readiness" do
    it "reports variants as ready once they are processed" do
      photo = attached_photo

      expect(photo.all_variants_ready?).to be false

      ImageProcessingJob.new.perform(photo.id)

      expect(photo.reload.all_variants_ready?).to be true
    end

    it "serves a real variant rather than always falling back to the original" do
      photo = attached_photo
      ImageProcessingJob.new.perform(photo.id)

      best = ImageProcessingService.best_available_variant(photo.reload, :thumbnail)

      expect(best).not_to eq(photo.image)
      expect(best.key).to be_present
    end
  end
end
