class AddMetadataToBulkUploads < ActiveRecord::Migration[8.0]
  def change
    add_column :bulk_uploads, :metadata, :text
  end
end
