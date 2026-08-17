class RequireSessionIdOnAlbumViewEvents < ActiveRecord::Migration[8.0]
  def up
    AlbumViewEvent.where(session_id: nil).update_all(session_id: "anonymous")
    change_column_null :album_view_events, :session_id, false
  end

  def down
    change_column_null :album_view_events, :session_id, true
  end
end
