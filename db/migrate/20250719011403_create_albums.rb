class CreateAlbums < ActiveRecord::Migration[8.0]
  def change
    create_table :albums do |t|
      t.string :name, null: false
      t.text :description
      t.references :user, null: false, foreign_key: true
      t.string :privacy, null: false, default: 'private'
      t.references :cover_photo, null: true, foreign_key: { to_table: :photos }

      t.timestamps
    end
    
    add_index :albums, :name
    add_index :albums, :privacy
    add_index :albums, [:user_id, :name]
  end
end
