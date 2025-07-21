class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Photo indexes for common queries (skip created_at as it already exists)
    add_index :photos, :taken_at unless index_exists?(:photos, :taken_at)
    add_index :photos, [:user_id, :created_at] unless index_exists?(:photos, [:user_id, :created_at])
    add_index :photos, [:user_id, :taken_at] unless index_exists?(:photos, [:user_id, :taken_at])
    
    # Album indexes for common queries
    add_index :albums, :created_at unless index_exists?(:albums, :created_at)
    add_index :albums, :updated_at unless index_exists?(:albums, :updated_at)
    add_index :albums, [:user_id, :created_at] unless index_exists?(:albums, [:user_id, :created_at])
    add_index :albums, [:privacy, :created_at] unless index_exists?(:albums, [:privacy, :created_at])
    
    # Family indexes for common queries
    add_index :families, :created_at unless index_exists?(:families, :created_at)
    add_index :families, [:created_by_id, :created_at] unless index_exists?(:families, [:created_by_id, :created_at])
    
    # Family membership indexes
    add_index :family_memberships, :joined_at unless index_exists?(:family_memberships, :joined_at)
    add_index :family_memberships, [:family_id, :role] unless index_exists?(:family_memberships, [:family_id, :role])
    
    # Family invitation indexes
    add_index :family_invitations, [:status, :created_at] unless index_exists?(:family_invitations, [:status, :created_at])
    add_index :family_invitations, [:family_id, :status] unless index_exists?(:family_invitations, [:family_id, :status])
    add_index :family_invitations, :expires_at unless index_exists?(:family_invitations, :expires_at)
    
    # User indexes for profile queries
    add_index :users, :created_at unless index_exists?(:users, :created_at)
    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL" unless index_exists?(:users, [:provider, :uid])
  end
end
