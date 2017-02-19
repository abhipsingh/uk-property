class AddUniqueIndexToAssignedAgents < ActiveRecord::Migration
  def change
    add_index(:agents_branches_assigned_agents, :email, {unique: true})
    #add_index(:property_users, :email, {unique: true})
    add_index(:vendors, :email, {unique: true})
  end
end
