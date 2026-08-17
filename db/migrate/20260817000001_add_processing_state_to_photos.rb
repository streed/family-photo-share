class AddProcessingStateToPhotos < ActiveRecord::Migration[8.0]
  # Photos previously had only `processing_completed_at`, so a photo whose image
  # job died was indistinguishable from one still in the queue: the UI showed
  # "Queue" forever and polled every two seconds with no terminal state.
  def up
    add_column :photos, :processing_state, :string, null: false, default: "pending"
    add_column :photos, :processing_error, :text
    add_column :photos, :processing_attempts, :integer, null: false, default: 0
    add_index :photos, :processing_state

    # Anything already finished is ready; everything else stays pending.
    execute <<~SQL
      UPDATE photos
         SET processing_state = 'ready'
       WHERE processing_completed_at IS NOT NULL
    SQL
  end

  def down
    remove_index :photos, :processing_state
    remove_column :photos, :processing_attempts
    remove_column :photos, :processing_error
    remove_column :photos, :processing_state
  end
end
