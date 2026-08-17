require 'rails_helper'

RSpec.describe BulkImageProcessingJob, type: :job do
  let(:user) { create(:user) }

  def stranded_photo(state: "pending", attempts: 0, stale: true)
    photo = Photo.new(user: user, title: "stranded")
    photo.image.attach(
      io: Rails.root.join("spec/fixtures/files/test_image.jpg").open,
      filename: "s.jpg",
      content_type: "image/jpeg"
    )
    photo.save!
    photo.update_columns(
      processing_state: state,
      processing_attempts: attempts,
      updated_at: stale ? 2.hours.ago : Time.current
    )
    photo
  end

  # Creating a Photo enqueues its own ImageProcessingJob via after_create_commit,
  # so record the ids the sweep itself enqueues rather than counting every call.
  let(:swept_ids) { [] }

  before do
    allow(ImageProcessingJob).to receive(:perform_async) { |id| swept_ids << id }
  end

  it "requeues a photo whose processing never completed" do
    photo = stranded_photo
    swept_ids.clear

    expect(described_class.new.perform).to eq(1)
    expect(swept_ids).to eq([ photo.id ])
  end

  it "leaves freshly uploaded photos alone" do
    stranded_photo(stale: false)
    swept_ids.clear

    expect(described_class.new.perform).to eq(0)
    expect(swept_ids).to be_empty
  end

  it "does not pick up a photo that is already being processed" do
    stranded_photo(state: "processing")

    expect(described_class.new.perform).to eq(0)
  end

  it "gives up on a photo that has exhausted its attempts" do
    stranded_photo(state: "failed", attempts: Photo::MAX_PROCESSING_ATTEMPTS)

    expect(described_class.new.perform).to eq(0)
  end

  it "retries a failed photo that still has attempts left" do
    stranded_photo(state: "failed", attempts: 1)

    expect(described_class.new.perform).to eq(1)
  end

  # The old implementation recounted photos immediately after enqueuing, before
  # any of that work could run, so it rescheduled itself forever.
  it "terminates instead of rescheduling itself indefinitely" do
    3.times { stranded_photo }
    allow(described_class).to receive(:perform_in)

    described_class.new.perform(10)

    expect(described_class).not_to have_received(:perform_in)
    expect(Photo.where(processing_state: "processing").count).to eq(3)
  end

  it "schedules a follow-up batch only while work remains" do
    3.times { stranded_photo }
    allow(described_class).to receive(:perform_in)

    described_class.new.perform(2)

    expect(described_class).to have_received(:perform_in).with(30.seconds, 2)
  end
end
