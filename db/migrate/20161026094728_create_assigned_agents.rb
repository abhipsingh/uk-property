class CreateAssignedAgents < ActiveRecord::Migration
  def change
    create_table :agents_branches_assigned_agents do |t|
      t.string :name
      t.string :email
      t.string :mobile
      t.integer :branch_id
    end
    
    add_index(:agents_branches_assigned_agents, :branch_id)
  end
end
