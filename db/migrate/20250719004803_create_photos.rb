class CreatePhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :photos do |t|
      t.string :title, null: false
      t.text :description
      t.references :user, null: false, foreign_key: true
      t.datetime :taken_at
      t.string :location
      t.string :original_filename
      t.integer :file_size
      t.string :content_type
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :photos, :taken_at
    add_index :photos, :created_at
  end
end
