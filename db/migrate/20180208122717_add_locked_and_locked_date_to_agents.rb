class AddLockedAndLockedDateToAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :locked, :boolean, default: false)
    add_column(:agents_branches_assigned_agents, :locked_date, :date)
  end
end

