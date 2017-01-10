class AddColumnsToAgentsBranchesAssignedAgents < ActiveRecord::Migration
  def change
    add_column :agents_branches_assigned_agents, :provider, :string
    add_column :agents_branches_assigned_agents, :uid, :string
  end
end
