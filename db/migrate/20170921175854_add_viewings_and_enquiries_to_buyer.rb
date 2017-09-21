class AddViewingsAndEnquiriesToBuyer < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :viewings, :integer)
    add_column(:property_buyers, :enquiries, :integer)
    change_column(:events, :type_of_match, :integer, limit: 2)
  end
end
