class AllowNullPhotoTitles < ActiveRecord::Migration[8.0]
  def change
    change_column_null :photos, :title, true
  end
end
