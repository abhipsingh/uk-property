class ModifyAttrsInSalePriceUuidUdprmMap < ActiveRecord::Migration
  def change
    remove_column(:sale_price_uuid_udprn_maps, :sale_prices)
    add_column(:sale_price_uuid_udprn_maps, :sale_price, :integer)
    add_column(:sale_price_uuid_udprn_maps, :sale_date, :date)
  end
end
