class AddExistingAgentIdToAssignedAgent < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :existing_agent_id, :integer)
  end
end
