require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#qr_code_data_url' do
    let(:test_url) { 'https://example.com/test' }
    
    it 'generates a valid data URL' do
      result = helper.qr_code_data_url(test_url)
      
      expect(result).to start_with('data:image/svg+xml;base64,')
      expect(result).to be_a(String)
      expect(result.length).to be > 100 # Should be a substantial base64 string
    end
    
    it 'generates different QR codes for different URLs' do
      url1 = 'https://example.com/album1'
      url2 = 'https://example.com/album2'
      
      qr1 = helper.qr_code_data_url(url1)
      qr2 = helper.qr_code_data_url(url2)
      
      expect(qr1).not_to eq(qr2)
    end
    
    it 'accepts custom size parameter' do
      result_small = helper.qr_code_data_url(test_url, size: 3)
      result_large = helper.qr_code_data_url(test_url, size: 8)
      
      expect(result_small).to start_with('data:image/svg+xml;base64,')
      expect(result_large).to start_with('data:image/svg+xml;base64,')
      expect(result_small.length).to be < result_large.length
    end
    
    it 'handles empty strings gracefully' do
      expect { helper.qr_code_data_url('') }.not_to raise_error
      result = helper.qr_code_data_url('')
      expect(result).to start_with('data:image/svg+xml;base64,')
    end
    
    it 'handles long URLs' do
      long_url = 'https://example.com/' + 'a' * 1000
      expect { helper.qr_code_data_url(long_url) }.not_to raise_error
    end
  end
end