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

      # No orphaned session is created here: `album_access_sessions` has a
      # foreign key to `albums` and Album `dependent: :destroy`s its sessions, so
      # a row pointing at a missing album cannot be produced. The job's
      # orphan sweep is defensive only.
    end

    it 'removes expired sessions' do
      expect { described_class.perform_now }
        .to change { AlbumAccessSession.expired.count }.from(2).to(0)
    end

    it 'keeps active sessions' do
      described_class.perform_now
      expect(AlbumAccessSession.active.count).to eq(2)
    end

    it 'leaves no orphaned sessions behind' do
      described_class.perform_now

      expect(AlbumAccessSession.where.missing(:album).count).to eq(0)
    end

    it 'removes a session when its album is destroyed' do
      expect { album.destroy }.to change { AlbumAccessSession.count }.from(4).to(0)
    end

    it 'returns cleanup statistics' do
      result = described_class.perform_now

      expect(result).to include(
        expired_sessions_removed: 2,
        orphaned_sessions_removed: 0,
        active_sessions_remaining: 2,
        cleaned_at: be_within(1.second).of(Time.current)
      )
    end

    it 'logs cleanup information' do
      # ActiveJob logs around the perform, so allow other :info calls through
      # and assert only on the messages this job emits.
      allow(Rails.logger).to receive(:info)

      described_class.perform_now

      expect(Rails.logger).to have_received(:info).with("Starting cleanup of expired guest sessions...")
      expect(Rails.logger).to have_received(:info).with("Cleaned up 2 expired guest sessions")
      expect(Rails.logger).to have_received(:info).with("Cleaned up 0 orphaned guest sessions")
      expect(Rails.logger).to have_received(:info).with("2 active guest sessions remaining")
    end
  end
end
