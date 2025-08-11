class RemovePasswordDigestFromAlbums < ActiveRecord::Migration[8.0]
  def change
    remove_column :albums, :password_digest, :string
  end
end
