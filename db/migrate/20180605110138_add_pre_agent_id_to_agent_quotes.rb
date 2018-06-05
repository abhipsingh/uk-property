class AddPreAgentIdToAgentQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :pre_agent_id, :integer)
  end
end

