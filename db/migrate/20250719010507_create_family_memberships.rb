class CreateFamilyMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :family_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :family, null: false, foreign_key: true
      t.string :role, null: false, default: 'member'
      t.datetime :joined_at, null: false

      t.timestamps
    end
    
    add_index :family_memberships, [:user_id, :family_id], unique: true
  end
end
