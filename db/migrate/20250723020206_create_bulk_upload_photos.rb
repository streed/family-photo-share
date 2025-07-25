class CreateBulkUploadPhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :bulk_upload_photos do |t|
      t.references :bulk_upload, null: false, foreign_key: true
      t.references :photo, null: false, foreign_key: true

      t.timestamps
    end
  end
end
