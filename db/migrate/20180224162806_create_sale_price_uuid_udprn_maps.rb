class CreateSalePriceUuidUdprnMaps < ActiveRecord::Migration
  def change
    create_table :sale_price_uuid_udprn_maps do |t|
      t.integer :udprn
      t.string  :uuid
    end
  end
end
