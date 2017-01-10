class AddColumnsToPropertyBuyers < ActiveRecord::Migration
  def change
    add_column :property_buyers, :provider, :string
    add_column :property_buyers, :uid, :string
  end
end
