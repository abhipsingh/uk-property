class AddBuyerNameToEvents < ActiveRecord::Migration
  def change
    remove_column(:events, :property_status_type)
    remove_column(:events, :buyer_email)
    remove_column(:events, :address)
    add_column(:events, :buyer_name, :string)
  end
end
