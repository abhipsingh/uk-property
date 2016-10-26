class AddStatusToPropertyBuyer < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :status, :integer)
  end
end
