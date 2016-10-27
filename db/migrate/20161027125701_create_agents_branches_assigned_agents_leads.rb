class CreateAgentsBranchesAssignedAgentsLeads < ActiveRecord::Migration
  def change
    create_table :agents_branches_assigned_agents_leads do |t|
      t.integer :property_id
      t.integer :agent_id
      t.string :district
      t.integer :vendor_id

      t.timestamps null: false
    end

    add_index(:agents_branches_assigned_agents_leads, :district)
    add_index(:agents_branches_assigned_agents_leads, :property_id)
    add_index(:agents_branches_assigned_agents_leads, :agent_id)
    add_index(:agents_branches_assigned_agents_leads, [:property_id, :agent_id, :vendor_id], unique: true, name: 'prop_agent')
  end
end
