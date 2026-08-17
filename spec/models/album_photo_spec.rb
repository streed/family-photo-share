require 'rails_helper'

RSpec.describe AlbumPhoto, type: :model do
  let(:user) { create(:user) }
  let(:album) { create(:album, user: user) }
  let(:photo) { create(:photo, user: user) }

  describe "validations" do
    it "assigns the next slot rather than rejecting the column default of 0" do
      ap = described_class.new(album: album, photo: photo, position: 0, added_at: Time.current)

      expect(ap).to be_valid
      expect(ap.position).to eq(1)
    end

    it "still rejects a non-positive position on update" do
      ap = described_class.create!(album: album, photo: photo)
      ap.position = 0

      expect(ap).not_to be_valid
      expect(ap.errors[:position]).to be_present
    end

    it "does not allow the same photo in an album twice" do
      album.add_photo(photo)
      duplicate = described_class.new(album: album, photo: photo, position: 2, added_at: Time.current)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:photo_id]).to be_present
    end

    it "allows the same photo in different albums" do
      other_album = create(:album, user: user, name: "Second")
      album.add_photo(photo)

      expect(other_album.add_photo(photo)).to be true
      expect(photo.reload.albums).to contain_exactly(album, other_album)
    end
  end

  describe "defaults" do
    it "assigns the next position and an added_at automatically" do
      first = described_class.create!(album: album, photo: photo)
      second = described_class.create!(album: album, photo: create(:photo, user: user))

      expect(first.position).to eq(1)
      expect(second.position).to eq(2)
      expect(first.added_at).to be_present
    end
  end

  describe "counter cache" do
    it "keeps Album#photo_count in step without a COUNT query" do
      expect {
        album.add_photo(photo)
      }.to change { album.reload.album_photos_count }.from(0).to(1)

      expect {
        album.remove_photo(photo)
      }.to change { album.reload.album_photos_count }.from(1).to(0)
    end
  end

  describe "scopes" do
    it "orders by position" do
      a = create(:photo, user: user)
      b = create(:photo, user: user)
      album.add_photo(a)
      album.add_photo(b)

      expect(album.album_photos.ordered.map(&:photo_id)).to eq([ a.id, b.id ])
    end
  end
end
