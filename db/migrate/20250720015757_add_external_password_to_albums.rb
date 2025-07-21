class AddExternalPasswordToAlbums < ActiveRecord::Migration[8.0]
  def change
    add_column :albums, :external_password, :string
  end
end
