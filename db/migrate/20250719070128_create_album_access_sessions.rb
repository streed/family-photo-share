class CreateAlbumAccessSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :album_access_sessions do |t|
      t.references :album, null: false, foreign_key: true
      t.string :session_token, null: false
      t.string :ip_address
      t.datetime :expires_at, null: false
      t.datetime :accessed_at, null: false

      t.timestamps
    end
    
    add_index :album_access_sessions, :session_token, unique: true
    add_index :album_access_sessions, [:album_id, :session_token]
    add_index :album_access_sessions, :expires_at
  end
end
