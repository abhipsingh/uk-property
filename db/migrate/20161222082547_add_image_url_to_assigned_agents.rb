class AddImageUrlToAssignedAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :image_url, :string)
  end
end
