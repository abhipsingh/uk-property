class AddPasswordToAgentsPropertyBuyersAndVendors < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :password, :string)
    add_column(:property_buyers, :password, :string)
    add_column(:vendors, :password, :string)
  end
end
