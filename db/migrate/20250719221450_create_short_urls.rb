class CreateShortUrls < ActiveRecord::Migration[8.0]
  def change
    create_table :short_urls do |t|
      t.string :token, null: false
      t.string :resource_type, null: false
      t.bigint :resource_id, null: false
      t.string :variant
      t.datetime :expires_at, null: false
      t.datetime :accessed_at
      t.integer :access_count, default: 0, null: false

      t.timestamps
    end
    
    add_index :short_urls, :token, unique: true
    add_index :short_urls, [:resource_type, :resource_id, :variant], name: 'index_short_urls_on_resource_and_variant'
    add_index :short_urls, :expires_at
  end
end
