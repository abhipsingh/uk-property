class AddAgentIdToInvitedAgent < ActiveRecord::Migration
  def change
    add_column(:invited_agents, :agent_id, :integer)
  end
end

