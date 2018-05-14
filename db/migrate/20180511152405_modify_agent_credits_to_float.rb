class ModifyAgentCreditsToFloat < ActiveRecord::Migration
  def change
    change_column(:agents_branches_assigned_agents, :credit, :float)
  end
end

