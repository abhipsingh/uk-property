class AddCorrectAgentIndexToQuotes < ActiveRecord::Migration
  def change
    execute("DROP INDEX quotes_unique_property_agents_idx")
    execute("CREATE UNIQUE INDEX quotes_unique_property_agents_idx ON agents_branches_assigned_agents_quotes(agent_id, property_id, expired) WHERE agent_id IS NOT NULL AND expired='f'")
  end
end

