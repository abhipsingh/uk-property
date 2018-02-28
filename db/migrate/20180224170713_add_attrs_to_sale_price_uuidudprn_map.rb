class AddAttrsToSalePriceUuidudprnMap < ActiveRecord::Migration
  def change
    add_column(:sale_price_uuid_udprn_maps, :property_type, :integer, limit: 2)
    add_column(:sale_price_uuid_udprn_maps, :sale_prices, :jsonb, default: '[]')
    add_column(:sale_price_uuid_udprn_maps, :tenure, :integer, limit: 2)
  end
end
