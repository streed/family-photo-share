require 'rails_helper'

RSpec.describe ImageProcessingService do
  let(:photo) { create(:photo) }

  describe '.variant_for_size' do
    it 'returns a variant for a known size' do
      variant = described_class.variant_for_size(photo, :thumbnail)
      expect(variant).to be_a(ActiveStorage::VariantWithRecord).or be_a(ActiveStorage::Variant)
    end

    it 'returns nil for an unknown size' do
      expect(described_class.variant_for_size(photo, :gigantic)).to be_nil
    end

    it 'returns nil when no image is attached' do
      photo.image.purge
      expect(described_class.variant_for_size(photo, :thumbnail)).to be_nil
    end

    it 'covers every defined size' do
      described_class::THUMBNAIL_SIZES.each_key do |size|
        expect(described_class.variant_for_size(photo, size)).not_to be_nil
      end
    end
  end

  describe '.all_variants_processed?' do
    it 'is false when photo has no image' do
      photo.image.purge
      expect(described_class.all_variants_processed?(photo)).to be false
    end

    it 'is false when processing has not completed' do
      photo.update_column(:processing_completed_at, nil)
      expect(described_class.all_variants_processed?(photo)).to be false
    end
  end

  describe '#process_all_variants' do
    it 'sets processing_completed_at when an image is attached' do
      service = described_class.new(photo)
      expect { service.process_all_variants }.to change { photo.reload.processing_completed_at }.from(nil)
    end

    it 'is a no-op when no image is attached' do
      photo.image.purge
      service = described_class.new(photo)
      expect { service.process_all_variants }.not_to change { photo.reload.processing_completed_at }
    end
  end
end
