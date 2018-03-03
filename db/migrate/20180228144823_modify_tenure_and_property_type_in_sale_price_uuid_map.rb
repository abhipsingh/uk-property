class ModifyTenureAndPropertyTypeInSalePriceUuidMap < ActiveRecord::Migration
  def change
    change_column(:sale_price_uuid_udprn_maps, :tenure, :string, limit: 1)
    change_column(:sale_price_uuid_udprn_maps, :property_type, :string, limit: 1)
  end
end
