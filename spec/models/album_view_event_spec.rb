require 'rails_helper'

RSpec.describe AlbumViewEvent, type: :model do
  describe 'associations' do
    it { should belong_to(:album) }
    it { should belong_to(:photo).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:event_type) }
    
    it 'validates event_type inclusion' do
      event = build(:album_view_event, event_type: 'invalid_type')
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to include('is not included in the list')
    end
    
    it 'accepts valid event types' do
      %w[password_entry password_attempt_failed photo_view].each do |event_type|
        event = build(:album_view_event, event_type: event_type)
        expect(event).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:recent_event) { create(:album_view_event, occurred_at: 3.days.ago) }
    let!(:old_event) { create(:album_view_event, occurred_at: 10.days.ago) }
    let!(:album) { create(:album) }
    let!(:album_event) { create(:album_view_event, album: album) }
    let!(:password_event) { create(:album_view_event, event_type: 'password_entry') }
    let!(:photo_event) { create(:album_view_event, event_type: 'photo_view') }
    
    describe '.recent' do
      it 'returns events from the last 7 days' do
        expect(AlbumViewEvent.recent).to include(recent_event)
        expect(AlbumViewEvent.recent).not_to include(old_event)
      end
    end
    
    describe '.for_album' do
      it 'returns events for a specific album' do
        expect(AlbumViewEvent.for_album(album)).to include(album_event)
        expect(AlbumViewEvent.for_album(album)).not_to include(recent_event)
      end
    end
    
    describe '.by_type' do
      it 'returns events of a specific type' do
        expect(AlbumViewEvent.by_type('password_entry')).to include(password_event)
        expect(AlbumViewEvent.by_type('password_entry')).not_to include(photo_event)
      end
    end
  end

  describe 'callbacks' do
    describe '#set_occurred_at' do
      it 'sets occurred_at if not provided' do
        event = build(:album_view_event, occurred_at: nil)
        expect { event.save! }.to change { event.occurred_at }.from(nil)
        expect(event.occurred_at).to be_within(1.second).of(Time.current)
      end
      
      it 'does not override occurred_at if provided' do
        specific_time = 2.hours.ago
        event = build(:album_view_event, occurred_at: specific_time)
        event.save!
        expect(event.occurred_at).to be_within(1.second).of(specific_time)
      end
    end
  end

  describe '.track_password_entry' do
    let(:album) { create(:album) }
    let(:request) { double('request', remote_ip: '127.0.0.1', user_agent: 'Test Browser', referrer: 'http://example.com') }
    let(:session_id) { 'test_session_123' }
    
    it 'creates a password entry event' do
      expect {
        AlbumViewEvent.track_password_entry(album, request, session_id)
      }.to change { AlbumViewEvent.count }.by(1)
      
      event = AlbumViewEvent.last
      expect(event.album).to eq(album)
      expect(event.event_type).to eq('password_entry')
      expect(event.ip_address).to eq('127.0.0.1')
      expect(event.user_agent).to eq('Test Browser')
      expect(event.referrer).to eq('http://example.com')
      expect(event.session_id).to eq(session_id)
      expect(event.photo).to be_nil
    end
  end

  describe '.track_failed_password_attempt' do
    let(:album) { create(:album) }
    let(:session) { double('session', id: 'evil_session_789') }
    let(:request) { double('request', remote_ip: '10.0.0.1', user_agent: 'Attack Browser', referrer: 'http://malicious.com', session: session) }
    
    it 'creates a failed password attempt event' do
      expect {
        AlbumViewEvent.track_failed_password_attempt(album, request)
      }.to change { AlbumViewEvent.count }.by(1)
      
      event = AlbumViewEvent.last
      expect(event.album).to eq(album)
      expect(event.event_type).to eq('password_attempt_failed')
      expect(event.ip_address).to eq('10.0.0.1')
      expect(event.user_agent).to eq('Attack Browser')
      expect(event.referrer).to eq('http://malicious.com')
      expect(event.session_id).to eq('evil_session_789')
      expect(event.photo).to be_nil
    end
  end

  describe '.track_photo_view' do
    let(:album) { create(:album) }
    let(:photo) { create(:photo) }
    let(:request) { double('request', remote_ip: '192.168.1.1', user_agent: 'Mobile Browser', referrer: 'http://social.com') }
    let(:session_id) { 'mobile_session_456' }
    
    it 'creates a photo view event' do
      expect {
        AlbumViewEvent.track_photo_view(album, photo, request, session_id)
      }.to change { AlbumViewEvent.count }.by(1)
      
      event = AlbumViewEvent.last
      expect(event.album).to eq(album)
      expect(event.photo).to eq(photo)
      expect(event.event_type).to eq('photo_view')
      expect(event.ip_address).to eq('192.168.1.1')
      expect(event.user_agent).to eq('Mobile Browser')
      expect(event.referrer).to eq('http://social.com')
      expect(event.session_id).to eq(session_id)
    end
  end
end
