class CreateFamilies < ActiveRecord::Migration[8.0]
  def change
    create_table :families do |t|
      t.string :name, null: false
      t.text :description
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    
    add_index :families, :name
  end
end
