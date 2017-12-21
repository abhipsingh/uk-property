class AddBranchIdToInvitedAgents < ActiveRecord::Migration
  def change
    add_column(:invited_agents, :branch_id, :integer)
  end
end

