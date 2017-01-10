class AddNewColumnsToAgentsBranchesAssignedAgents < ActiveRecord::Migration
  def change
    add_column :agents_branches_assigned_agents, :oauth_token, :string
    add_column :agents_branches_assigned_agents, :oauth_expires_at, :datetime
  end
end
