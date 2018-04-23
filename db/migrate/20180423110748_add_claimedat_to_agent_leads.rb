class AddClaimedatToAgentLeads < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_leads, :claimed_at, :timestamp)
  end
end

