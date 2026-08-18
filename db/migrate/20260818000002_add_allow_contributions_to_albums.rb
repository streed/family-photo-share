class AddAllowContributionsToAlbums < ActiveRecord::Migration[8.0]
  # Until now an album was strictly one person's: Album#editable_by? is
  # `self.user == user`, so a "family" album was read-only to the entire family
  # and only its creator could ever put a photo in it. This flag opens a family
  # album up so every member can add their own photos to the shared one.
  def change
    add_column :albums, :allow_contributions, :boolean, null: false, default: false
  end
end
