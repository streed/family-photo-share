class CreateIpLocations < ActiveRecord::Migration[8.0]
  # A shared, per-IP cache of geolocation lookups.
  #
  # Guest activity records an IP on every event and every session; resolving that
  # to a place is a network call, so the answer is cached here once per address
  # and reused by every row that shares it.
  def change
    create_table :ip_locations do |t|
      t.string :ip_address, null: false
      t.string :status, null: false, default: "pending"
      t.string :city
      t.string :region
      t.string :country
      t.string :country_code
      t.string :postal_code
      t.string :timezone
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.string :provider
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :ip_locations, :ip_address, unique: true
    add_index :ip_locations, :resolved_at
  end
end
