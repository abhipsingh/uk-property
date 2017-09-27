class AddPremiumExpiresAtToAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :premium_expires_at, :date)
  end
end
