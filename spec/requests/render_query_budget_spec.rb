require 'rails_helper'

# Guards against the N+1 and write-on-read that made album pages issue hundreds
# of queries: ShortUrl.for_photo_variant ran a SELECT (and often an INSERT) per
# photo per variant while the view was rendering.
RSpec.describe "Render query budgets", type: :request do
  let(:user) { create(:user) }

  def count_queries
    total = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s =~ /SCHEMA|TRANSACTION/
      total += 1
    end
    yield
    total
  ensure
    ActiveSupport::Notifications.unsubscribe(sub) if sub
  end

  def photo_with_image(title)
    photo = Photo.new(user: user, title: title)
    photo.image.attach(
      io: Rails.root.join("spec/fixtures/files/test_image.jpg").open,
      filename: "#{title}.jpg",
      content_type: "image/jpeg"
    )
    photo.save!
    photo
  end

  before { sign_in user }

  describe "album show" do
    it "does not scale its query count with the number of photos" do
      album = create(:album, user: user, privacy: "family")
      20.times { |i| album.add_photo(photo_with_image("p#{i}")) }
      5.times { |i| photo_with_image("spare#{i}") }

      # Warm once so the comparison isn't dominated by first-time row creation.
      get album_path(album)

      queries = count_queries { get album_path(album) }

      expect(response).to have_http_status(:success)
      expect(queries).to be < 40, "album show issued #{queries} queries for 20 photos"
    end

    it "stops writing new short_urls rows on every render" do
      album = create(:album, user: user, privacy: "family")
      5.times { |i| album.add_photo(photo_with_image("q#{i}")) }

      get album_path(album)
      rows_after_first = ShortUrl.count

      get album_path(album)
      get album_path(album)

      expect(ShortUrl.count).to eq(rows_after_first)
    end
  end

  describe "albums index" do
    it "does not scale its query count with the number of albums" do
      10.times do |i|
        album = create(:album, user: user, name: "Album #{i}")
        album.add_photo(photo_with_image("cover#{i}"))
      end

      get albums_path
      queries = count_queries { get albums_path }

      expect(response).to have_http_status(:success)
      expect(queries).to be < 20, "albums index issued #{queries} queries for 10 albums"
    end
  end

  describe "photo_count" do
    it "is served from a counter cache rather than a COUNT query" do
      album = create(:album, user: user)
      photo = create(:photo, user: user)

      expect { album.add_photo(photo) }.to change { album.reload.album_photos_count }.from(0).to(1)
      expect(album.photo_count).to eq(1)

      expect { album.remove_photo(photo) }.to change { album.reload.album_photos_count }.from(1).to(0)
    end
  end
end
