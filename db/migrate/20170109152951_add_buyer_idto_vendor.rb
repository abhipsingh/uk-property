class AddBuyerIdtoVendor < ActiveRecord::Migration
  def change
    add_column(:vendors, :buyer_id, :integer)
  end
end
