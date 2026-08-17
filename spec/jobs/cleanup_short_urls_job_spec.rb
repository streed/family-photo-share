require 'rails_helper'

RSpec.describe CleanupShortUrlsJob, type: :job do
  let(:photo) { create(:photo) }

  it "removes expired short URLs" do
    expired = ShortUrl.for_photo_variant(photo, :thumbnail)
    expired.update_column(:expires_at, 1.day.ago)
    active = ShortUrl.for_photo_variant(photo, :large)

    expect { described_class.perform_now }.to change { ShortUrl.count }.by(-1)
    expect(ShortUrl.exists?(active.id)).to be true
    expect(ShortUrl.exists?(expired.id)).to be false
  end

  it "reports what it removed" do
    su = ShortUrl.for_photo_variant(photo, :thumbnail)
    su.update_column(:expires_at, 1.day.ago)

    result = described_class.perform_now

    expect(result).to include(expired_short_urls_removed: 1, remaining: 0)
  end

  it "is a no-op when nothing has expired" do
    ShortUrl.for_photo_variant(photo, :thumbnail)

    expect { described_class.perform_now }.not_to change { ShortUrl.count }
  end
end
