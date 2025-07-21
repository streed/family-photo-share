class AddMetadataFieldsToPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :photos, :latitude, :decimal, precision: 10, scale: 6
    add_column :photos, :longitude, :decimal, precision: 10, scale: 6
    add_column :photos, :camera_make, :string
    add_column :photos, :camera_model, :string
  end
end
