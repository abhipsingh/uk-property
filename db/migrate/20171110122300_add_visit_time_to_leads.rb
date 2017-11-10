class AddVisitTimeToLeads < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_leads, :visit_time, :datetime)
  end
end

