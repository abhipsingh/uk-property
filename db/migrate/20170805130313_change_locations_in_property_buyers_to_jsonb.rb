class ChangeLocationsInPropertyBuyersToJsonb < ActiveRecord::Migration
  def change
    remove_column(:property_buyers, :locations)
    add_column(:property_buyers, :locations, :jsonb)
  end
end
