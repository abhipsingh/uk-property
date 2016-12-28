class AddInvitedAgentsToAssignedAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :invited_agents, :jsonb)
  end
end
