class EnforceSingleFamilyPerUser < ActiveRecord::Migration[8.0]
  def up
    # First, ensure each user is only in one family (keep the first membership)
    execute <<-SQL
      DELETE FROM family_memberships fm1
      WHERE fm1.id NOT IN (
        SELECT MIN(fm2.id)
        FROM (SELECT * FROM family_memberships) fm2
        GROUP BY fm2.user_id
      )
    SQL
    
    # Remove existing indexes on user_id
    if index_exists?(:family_memberships, [:user_id, :family_id])
      remove_index :family_memberships, [:user_id, :family_id]
    end
    
    if index_exists?(:family_memberships, :user_id)
      remove_index :family_memberships, :user_id
    end
    
    # Add a unique index on user_id to enforce one family per user
    add_index :family_memberships, :user_id, unique: true
    
    # Keep the family_id index for queries
    add_index :family_memberships, :family_id unless index_exists?(:family_memberships, :family_id)
  end
  
  def down
    # Remove the unique constraint on user_id
    remove_index :family_memberships, :user_id if index_exists?(:family_memberships, :user_id)
    
    # Restore the original composite index
    add_index :family_memberships, [:user_id, :family_id], unique: true unless index_exists?(:family_memberships, [:user_id, :family_id])
  end
end