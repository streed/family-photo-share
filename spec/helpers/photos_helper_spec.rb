require 'rails_helper'

RSpec.describe PhotosHelper, type: :helper do
  describe '#photo_title_or_default' do
    it 'returns the photo title when present' do
      photo = build(:photo, title: 'My Great Photo')
      expect(helper.photo_title_or_default(photo)).to eq('My Great Photo')
    end
    
    it 'returns "Untitled Photo" when title is nil' do
      photo = build(:photo, title: nil)
      expect(helper.photo_title_or_default(photo)).to eq('Untitled Photo')
    end
    
    it 'returns "Untitled Photo" when title is empty string' do
      photo = build(:photo, title: '')
      expect(helper.photo_title_or_default(photo)).to eq('Untitled Photo')
    end
    
    it 'returns "Untitled Photo" when title is only whitespace' do
      photo = build(:photo, title: '   ')
      expect(helper.photo_title_or_default(photo)).to eq('Untitled Photo')
    end
  end
  
  describe '#truncated_photo_title' do
    it 'truncates long titles with default length' do
      photo = build(:photo, title: 'This is a very long title that should be truncated')
      expect(helper.truncated_photo_title(photo)).to eq('This is a very long title t...')
    end
    
    it 'truncates long titles with custom length' do
      photo = build(:photo, title: 'This is a very long title')
      expect(helper.truncated_photo_title(photo, length: 10)).to eq('This is...')
    end
    
    it 'does not truncate short titles' do
      photo = build(:photo, title: 'Short')
      expect(helper.truncated_photo_title(photo)).to eq('Short')
    end
    
    it 'uses default text for nil titles' do
      photo = build(:photo, title: nil)
      expect(helper.truncated_photo_title(photo, length: 10)).to eq('Untitle...')
    end
    
    it 'uses default text for empty titles' do
      photo = build(:photo, title: '')
      expect(helper.truncated_photo_title(photo)).to eq('Untitled Photo')
    end
  end
end