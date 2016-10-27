class CreateAgentsBranchesAssignedAgentsQuotes < ActiveRecord::Migration
  def change
    create_table :agents_branches_assigned_agents_quotes do |t|
      t.datetime :deadline
      t.integer :agent_id
      t.integer :property_id
      t.integer :status
      t.string :payment_terms
      t.jsonb :quote_details
      t.boolean :service_required

      t.timestamps null: false
    end
  end
end
