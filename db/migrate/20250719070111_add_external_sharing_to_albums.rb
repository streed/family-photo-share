class AddExternalSharingToAlbums < ActiveRecord::Migration[8.0]
  def change
    add_column :albums, :password_digest, :string
    add_column :albums, :allow_external_access, :boolean, default: false, null: false
    add_column :albums, :sharing_token, :string
    
    add_index :albums, :sharing_token, unique: true
    add_index :albums, :allow_external_access
  end
end
