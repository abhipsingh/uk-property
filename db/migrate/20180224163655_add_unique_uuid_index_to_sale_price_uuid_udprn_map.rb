class AddUniqueUuidIndexToSalePriceUuidUdprnMap < ActiveRecord::Migration
  def change
    add_index(:sale_price_uuid_udprn_maps, :uuid, unique: true)
    #execute("ALTER TABLE sale_price_uuid_udprn_maps DROP CONSTRAINT sale_price_uuid_udprn_maps_pkey ")
    #execute("ALTER TABLE sale_price_uuid_udprn_maps DROP COLUMN id")
  end
end
