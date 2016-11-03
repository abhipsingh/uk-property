class AddAdditionalColumnsToPropertyBuyer < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :buying_status, :integer)
    add_column(:property_buyers, :funding, :integer)
    add_column(:property_buyers, :mortgage_approval, :integer)
    add_column(:property_buyers, :biggest_problem, :integer)
  end
end
