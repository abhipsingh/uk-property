class AddSourceAndBranchIdToAgentsLeads < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_leads, :source, :integer, limit: 2)
    add_column(:agents_branches_assigned_agents_leads, :branch_id, :integer)
    add_index(:agents_branches_assigned_agents_leads, [:source, :branch_id], name: 'leads_source_branch_idx')
  end
end

