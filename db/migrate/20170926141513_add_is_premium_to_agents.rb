class AddIsPremiumToAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :is_premium, :boolean, default: false)
  end
end
