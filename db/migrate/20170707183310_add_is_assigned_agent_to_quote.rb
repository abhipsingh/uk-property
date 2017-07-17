class AddIsAssignedAgentToQuote < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :is_assigned_agent, :boolean)
  end
end
