class AddRefundStatusToAgentQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :refund_status, :boolean, default: false)
  end
end
