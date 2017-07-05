class AddPropertyStatusTypeToMultipleTables < ActiveRecord::Migration
  def change
    add_column(:events, :property_status_type, :integer)
    add_column(:agents_branches_assigned_agents_leads, :property_status_type, :integer)
    add_column(:agents_branches_assigned_agents_quotes, :property_status_type, :integer)
  end
end
