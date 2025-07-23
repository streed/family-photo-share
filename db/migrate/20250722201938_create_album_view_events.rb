class CreateAlbumViewEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :album_view_events do |t|
      t.references :album, null: false, foreign_key: true
      t.string :event_type, null: false
      t.references :photo, null: true, foreign_key: true
      t.string :ip_address
      t.text :user_agent
      t.string :referrer
      t.string :session_id
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :album_view_events, :event_type
    add_index :album_view_events, :occurred_at
    add_index :album_view_events, [:album_id, :occurred_at]
    add_index :album_view_events, :session_id
  end
end
