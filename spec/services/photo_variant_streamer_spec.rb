require 'rails_helper'

RSpec.describe PhotoVariantStreamer do
  let(:photo) { create(:photo) }

  describe '.call' do
    it 'returns a disk Result for an attached photo on disk service' do
      result = described_class.call(photo: photo, variant: "original")

      expect(result).to be_a(PhotoVariantStreamer::Result)
      expect(result).to be_disk
      expect(result.path).to be_present
      expect(File.exist?(result.path)).to be true
      expect(result.content_type).to eq("image/jpeg")
      expect(result.filename).to end_with(".jpg")
    end

    it 'returns nil when the photo has no attached image' do
      photo.image.purge
      result = described_class.call(photo: photo, variant: "original")
      expect(result).to be_nil
    end

    it 'falls back to the original image when a variant raises FileNotFoundError' do
      allow(photo).to receive(:thumbnail).and_raise(ActiveStorage::FileNotFoundError)

      result = described_class.call(photo: photo, variant: "thumbnail")

      expect(result).not_to be_nil
      expect(result.content_type).to eq("image/jpeg")
    end

    it 'derives the filename from the photo title' do
      photo.update!(title: "My Best Shot!")
      result = described_class.call(photo: photo, variant: "original")
      expect(result.filename).to eq("my-best-shot.jpg")
    end

    it 'falls back to "photo" when title is blank' do
      photo.update_column(:title, nil)
      result = described_class.call(photo: photo, variant: "original")
      expect(result.filename).to eq("photo.jpg")
    end
  end
end
