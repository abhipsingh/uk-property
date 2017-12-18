class AddCreatedAtToAssignedAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :created_at, :timestamp)
  end
end

