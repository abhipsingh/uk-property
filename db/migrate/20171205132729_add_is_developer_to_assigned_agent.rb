class AddIsDeveloperToAssignedAgent < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :is_developer, :boolean, default: false)
    add_column(:agents_branches, :is_developer, :boolean, default: false)
    add_column(:agents, :is_developer, :boolean, default: false)
    add_column(:agents_groups, :is_developer, :boolean, default: false)
  end
end

