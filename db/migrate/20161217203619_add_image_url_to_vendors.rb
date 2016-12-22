class AddImageUrlToVendors < ActiveRecord::Migration
  def change
    add_column(:vendors, :image_url, :string)
  end
end
