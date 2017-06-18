class AddLeadStatusToAgentsLeads < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_leads, :submitted, :boolean)
  end
end
