class AddAmountToAssignedAgentQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :amount, :integer)
  end
end

