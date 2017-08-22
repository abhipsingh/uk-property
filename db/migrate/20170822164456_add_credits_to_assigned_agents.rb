class AddCreditsToAssignedAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :credit, :integer, default: 0)
  end
end
