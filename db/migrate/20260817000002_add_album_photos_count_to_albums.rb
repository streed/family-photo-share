class AddAlbumPhotosCountToAlbums < ActiveRecord::Migration[8.0]
  # Album#photo_count issued a COUNT(*) every time it was called — several times
  # per album page and once per tile on the albums index.
  def up
    add_column :albums, :album_photos_count, :integer, null: false, default: 0

    execute <<~SQL
      UPDATE albums
         SET album_photos_count = (
           SELECT COUNT(*) FROM album_photos WHERE album_photos.album_id = albums.id
         )
    SQL
  end

  def down
    remove_column :albums, :album_photos_count
  end
end
