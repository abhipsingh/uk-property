class AddPremiumToPropertyBuyer < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :is_premium, :boolean, default: false)
  end
end
