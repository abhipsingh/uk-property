class AddEntityIdToInvitedDevelopersAndAgents < ActiveRecord::Migration
  def change
    add_column(:invited_developers, :entity_id, :integer)
    add_column(:invited_agents, :entity_id, :integer)
    remove_column(:invited_developers, :developer_id, :integer)
    remove_column(:invited_agents, :agent_id, :integer)
  end
end

