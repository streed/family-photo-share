require 'rails_helper'

RSpec.describe CleanupAlbumViewEventsJob, type: :job do
  describe '#perform' do
    let!(:recent_event1) { create(:album_view_event, occurred_at: 3.days.ago) }
    let!(:recent_event2) { create(:album_view_event, occurred_at: 6.days.ago) }
    let!(:old_event1) { create(:album_view_event, occurred_at: 8.days.ago) }
    let!(:old_event2) { create(:album_view_event, occurred_at: 15.days.ago) }
    let!(:old_event3) { create(:album_view_event, occurred_at: 30.days.ago) }

    it 'deletes events older than 7 days' do
      expect { described_class.new.perform }.to change { AlbumViewEvent.count }.from(5).to(2)

      # Recent events should remain
      expect(AlbumViewEvent.exists?(recent_event1.id)).to be true
      expect(AlbumViewEvent.exists?(recent_event2.id)).to be true

      # Old events should be deleted
      expect(AlbumViewEvent.exists?(old_event1.id)).to be false
      expect(AlbumViewEvent.exists?(old_event2.id)).to be false
      expect(AlbumViewEvent.exists?(old_event3.id)).to be false
    end

    it 'logs the deletion count' do
      expect(Rails.logger).to receive(:info).with(/Deleted 3 old album view events/)
      described_class.new.perform
    end

    it 'handles when there are no old events' do
      AlbumViewEvent.where('occurred_at < ?', 7.days.ago).destroy_all

      expect { described_class.new.perform }.not_to change { AlbumViewEvent.count }
      expect(Rails.logger).to receive(:info).with(/Deleted 0 old album view events/)
      described_class.new.perform
    end
  end

  describe 'queue configuration' do
    it 'uses the low priority queue' do
      expect(described_class.new.queue_name).to eq('low')
    end
  end
end
