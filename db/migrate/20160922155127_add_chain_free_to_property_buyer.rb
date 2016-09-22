class AddChainFreeToPropertyBuyer < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :chain_free, :boolean)
  end
end
