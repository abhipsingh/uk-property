class AddOwnedByToLeads < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_leads, :owned_property, :boolean, default: false)
  end
end

