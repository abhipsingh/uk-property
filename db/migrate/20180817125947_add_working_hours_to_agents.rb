class AddWorkingHoursToAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :working_hours, :jsonb)
    add_column(:vendors, :working_hours, :jsonb)
  end
end

