class AddNameEmailAndMobileToPropertyBuyer < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :full_name, :string)
    add_column(:property_buyers, :email, :string)
    add_column(:property_buyers, :mobile, :string)
  end
end
