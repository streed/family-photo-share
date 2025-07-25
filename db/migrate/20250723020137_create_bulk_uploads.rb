class CreateBulkUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :bulk_uploads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :album, null: true, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.integer :total_count, default: 0, null: false
      t.integer :processed_count, default: 0, null: false
      t.integer :failed_count, default: 0, null: false
      t.text :error_messages

      t.timestamps
    end
    
    add_index :bulk_uploads, :status
    add_index :bulk_uploads, [:user_id, :created_at]
  end
end
