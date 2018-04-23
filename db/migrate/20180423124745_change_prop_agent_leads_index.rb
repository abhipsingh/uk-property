class ChangePropAgentLeadsIndex < ActiveRecord::Migration
  def change
    remove_index(:agents_branches_assigned_agents_leads,  name: 'prop_agent')
    execute("CREATE UNIQUE INDEX prop_agent_leads ON agents_branches_assigned_agents_leads(property_id, agent_id, vendor_id) WHERE expired='f'")
  end
end
