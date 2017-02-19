class AddInvitedAgentsToBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :invited_agents, :jsonb)
  end
end
