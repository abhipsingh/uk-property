class AddNameAndImageUrlToVendorAndPropertyBuyers < ActiveRecord::Migration
  def change
    add_column(:vendors, :name, :string)
    add_column(:property_buyers, :image_url, :string)
  end
end
