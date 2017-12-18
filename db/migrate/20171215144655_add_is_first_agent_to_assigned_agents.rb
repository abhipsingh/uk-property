class AddIsFirstAgentToAssignedAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :is_first_agent, :boolean)
  end
end

