class AddGroupIdToAgents < ActiveRecord::Migration
  def change
    add_column(:agents, :group_id, :integer)
    add_index(:agents, :group_id)
  end
end
