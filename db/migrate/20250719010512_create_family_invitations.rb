class CreateFamilyInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :family_invitations do |t|
      t.references :family, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :token, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :expires_at, null: false

      t.timestamps
    end
    
    add_index :family_invitations, :token, unique: true
    add_index :family_invitations, :email
    add_index :family_invitations, [:family_id, :email], unique: true
  end
end
