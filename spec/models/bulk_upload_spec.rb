require 'rails_helper'

RSpec.describe BulkUpload, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:album).optional }
    it { should have_many(:bulk_upload_photos).dependent(:destroy) }
    it { should have_many(:photos).through(:bulk_upload_photos) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:status).in_array(BulkUpload::STATUSES.values) }
  end

  describe 'status methods' do
    let(:bulk_upload) { create(:bulk_upload) }

    it 'responds to status query methods' do
      expect(bulk_upload).to respond_to(:pending?)
      expect(bulk_upload).to respond_to(:processing?)
      expect(bulk_upload).to respond_to(:completed?)
      expect(bulk_upload).to respond_to(:failed?)
      expect(bulk_upload).to respond_to(:partial?)
    end

    it 'returns correct status for pending bulk upload' do
      bulk_upload.update!(status: 'pending')
      expect(bulk_upload.pending?).to be true
      expect(bulk_upload.processing?).to be false
    end

    it 'returns correct status for processing bulk upload' do
      bulk_upload.update!(status: 'processing')
      expect(bulk_upload.processing?).to be true
      expect(bulk_upload.pending?).to be false
    end
  end

  describe '#success_rate' do
    let(:bulk_upload) { create(:bulk_upload, total_count: 10, processed_count: 8, failed_count: 2) }

    it 'calculates success rate correctly' do
      expect(bulk_upload.success_rate).to eq(60.0)
    end

    it 'returns 0 when total_count is 0' do
      bulk_upload.update!(total_count: 0)
      expect(bulk_upload.success_rate).to eq(0)
    end
  end

  describe '#add_error' do
    let(:bulk_upload) { create(:bulk_upload) }

    it 'adds error message' do
      bulk_upload.add_error('test.jpg', 'File too large')
      expect(bulk_upload.error_messages).to include('test.jpg: File too large')
    end

    it 'appends multiple error messages' do
      bulk_upload.add_error('test1.jpg', 'Error 1')
      bulk_upload.add_error('test2.jpg', 'Error 2')
      expect(bulk_upload.error_messages).to include('test1.jpg: Error 1')
      expect(bulk_upload.error_messages).to include('test2.jpg: Error 2')
    end
  end
end
