class AddIsPremiumToVendor < ActiveRecord::Migration
  def change
    add_column(:vendors, :is_premium, :boolean, default: false)
  end
end
