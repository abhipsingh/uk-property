class AddOpeningHoursToAssignedAgent < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :opening_hours, :jsonb)
  end
end
