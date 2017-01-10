class AddVendorIdtoBuyer < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :vendor_id,  :integer)
  end
end
