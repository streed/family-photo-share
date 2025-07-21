class AddProcessingCompletedAtToPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :photos, :processing_completed_at, :datetime
  end
end
