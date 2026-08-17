require 'rails_helper'

RSpec.describe ShortUrl, type: :model do
  let(:user) { create(:user) }
  let(:photo) { create(:photo, user: user) }

  describe ".for_photo_variant" do
    it "creates one row per photo and variant" do
      thumb = described_class.for_photo_variant(photo, :thumbnail)
      large = described_class.for_photo_variant(photo, :large)

      expect(thumb.variant).to eq("thumbnail")
      expect(large.variant).to eq("large")
      expect(described_class.count).to eq(2)
    end

    it "reuses an existing active row rather than minting another" do
      first = described_class.for_photo_variant(photo, :thumbnail)

      expect {
        described_class.for_photo_variant(photo.reload, :thumbnail)
      }.not_to change { described_class.count }

      expect(described_class.for_photo_variant(photo.reload, :thumbnail).token).to eq(first.token)
    end

    it "mints a replacement once the old row has expired" do
      old = described_class.for_photo_variant(photo, :thumbnail)
      old.update_column(:expires_at, 1.day.ago)

      fresh = described_class.for_photo_variant(photo.reload, :thumbnail)

      expect(fresh.id).not_to eq(old.id)
      expect(fresh).not_to be_expired
    end

    it "answers from the photo's cache without querying again" do
      described_class.warm_for_photos([ photo ], [ :thumbnail ])

      expect(described_class).not_to receive(:create!)
      expect(photo.short_thumbnail_url).to match(%r{\A/s/})
    end
  end

  describe ".warm_for_photos" do
    let(:photos) { create_list(:photo, 3, user: user) }

    it "resolves every photo and variant pair up front" do
      described_class.warm_for_photos(photos, [ :thumbnail, :large ])

      photos.each do |p|
        expect(p.short_url_cache.keys).to contain_exactly("thumbnail", "large")
      end
      expect(described_class.count).to eq(6)
    end

    it "does not create duplicates when some rows already exist" do
      described_class.for_photo_variant(photos.first, :thumbnail)

      expect {
        described_class.warm_for_photos(photos, [ :thumbnail ])
      }.to change { described_class.count }.by(2)
    end

    it "renders the whole set without further inserts" do
      described_class.warm_for_photos(photos, [ :thumbnail ])

      expect {
        photos.each(&:short_thumbnail_url)
      }.not_to change { described_class.count }
    end

    it "ignores unsaved or empty input" do
      expect { described_class.warm_for_photos([], [ :thumbnail ]) }.not_to raise_error
      expect { described_class.warm_for_photos(photos, []) }.not_to raise_error
      expect { described_class.warm_for_photos([ Photo.new ], [ :thumbnail ]) }.not_to raise_error
    end
  end

  describe "tokens" do
    it "assigns a unique url-safe token" do
      tokens = create_list(:photo, 5, user: user).map do |p|
        described_class.for_photo_variant(p, :thumbnail).token
      end

      expect(tokens.uniq.size).to eq(5)
      tokens.each { |t| expect(t).to match(/\A[A-Za-z0-9_-]+\z/) }
    end

    it "defaults to a 7 day expiry" do
      su = described_class.for_photo_variant(photo, :thumbnail)
      expect(su.expires_at).to be_within(1.minute).of(7.days.from_now)
    end
  end

  describe "#short_path" do
    it "is the /s/:token route" do
      su = described_class.for_photo_variant(photo, :thumbnail)
      expect(su.short_path).to eq("/s/#{su.token}")
    end
  end

  describe "#track_access!" do
    it "records the hit" do
      su = described_class.for_photo_variant(photo, :thumbnail)

      expect { su.track_access! }.to change { su.reload.access_count }.from(0).to(1)
      expect(su.accessed_at).to be_present
    end
  end

  describe "expiry scopes and cleanup" do
    it "separates active from expired rows" do
      active = described_class.for_photo_variant(photo, :thumbnail)
      expired = described_class.for_photo_variant(photo, :large)
      expired.update_column(:expires_at, 1.hour.ago)

      expect(described_class.active).to contain_exactly(active)
      expect(described_class.expired).to contain_exactly(expired)
    end

    it "deletes only expired rows" do
      active = described_class.for_photo_variant(photo, :thumbnail)
      expired = described_class.for_photo_variant(photo, :large)
      expired.update_column(:expires_at, 1.hour.ago)

      described_class.cleanup_expired!

      expect(described_class.all).to contain_exactly(active)
    end
  end
end
