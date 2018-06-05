class ChangeBranchIdInLeadsToPreAgentId < ActiveRecord::Migration
  def change
    remove_column(:agents_branches_assigned_agents_leads, :branch_id, :integer)
    add_column(:agents_branches_assigned_agents_leads, :pre_agent_id, :integer)
  end
end
