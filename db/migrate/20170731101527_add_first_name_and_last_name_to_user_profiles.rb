class AddFirstNameAndLastNameToUserProfiles < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :first_name, :string)
    add_column(:agents_branches_assigned_agents, :last_name, :string)
    add_column(:property_buyers, :first_name, :string)
    add_column(:property_buyers, :last_name, :string)
    add_column(:vendors, :first_name, :string)
    add_column(:vendors, :last_name, :string)
  end
end
