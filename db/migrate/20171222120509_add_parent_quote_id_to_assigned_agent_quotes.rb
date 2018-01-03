class AddParentQuoteIdToAssignedAgentQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :parent_quote_id, :integer)
  end
end

