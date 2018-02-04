class AddStatusToLeads < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_leads, :expired, :boolean, default: false)
  end
end

