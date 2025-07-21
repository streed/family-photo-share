require 'rails_helper'

RSpec.describe CleanupExpiredSessionsJob, type: :job do
  describe '#perform' do
    let(:album) { create(:album, allow_external_access: true) }
    let(:expired_time) { 2.days.ago }
    let(:active_time) { 1.hour.from_now }
    
    before do
      # Create expired sessions
      create(:album_access_session, album: album, expires_at: expired_time, accessed_at: expired_time)
      create(:album_access_session, album: album, expires_at: expired_time, accessed_at: expired_time)
      
      # Create active sessions
      create(:album_access_session, album: album, expires_at: active_time, accessed_at: Time.current)
      create(:album_access_session, album: album, expires_at: active_time, accessed_at: Time.current)
      
      # Create orphaned session (album deleted)
      orphaned_session = create(:album_access_session, album: album, expires_at: active_time)
      album_id = orphaned_session.album_id
      album.destroy
      orphaned_session.update_column(:album_id, album_id) # Restore the ID to simulate orphaned state
    end
    
    it 'removes expired sessions' do
      expect { described_class.perform_now }
        .to change { AlbumAccessSession.expired.count }.from(2).to(0)
    end
    
    it 'keeps active sessions' do
      described_class.perform_now
      expect(AlbumAccessSession.active.count).to eq(2)
    end
    
    it 'removes orphaned sessions' do
      orphaned_count = AlbumAccessSession.left_joins(:album).where(albums: { id: nil }).count
      expect(orphaned_count).to eq(1)
      
      described_class.perform_now
      
      orphaned_count_after = AlbumAccessSession.left_joins(:album).where(albums: { id: nil }).count
      expect(orphaned_count_after).to eq(0)
    end
    
    it 'returns cleanup statistics' do
      result = described_class.perform_now
      
      expect(result).to include(
        expired_sessions_removed: 2,
        orphaned_sessions_removed: 1,
        active_sessions_remaining: 2,
        cleaned_at: be_within(1.second).of(Time.current)
      )
    end
    
    it 'logs cleanup information' do
      expect(Rails.logger).to receive(:info).with("Starting cleanup of expired guest sessions...")
      expect(Rails.logger).to receive(:info).with("Cleaned up 2 expired guest sessions")
      expect(Rails.logger).to receive(:info).with("Cleaned up 1 orphaned guest sessions")
      expect(Rails.logger).to receive(:info).with("2 active guest sessions remaining")
      
      described_class.perform_now
    end
  end
end