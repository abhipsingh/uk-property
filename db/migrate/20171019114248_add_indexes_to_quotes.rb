class AddIndexesToQuotes < ActiveRecord::Migration
  def up
    execute("CREATE UNIQUE INDEX quotes_unique_property_idx ON agents_branches_assigned_agents_quotes(property_id) WHERE agent_id IS NULL")
    execute("CREATE UNIQUE INDEX quotes_unique_property_agents_idx ON agents_branches_assigned_agents_quotes(agent_id, property_id) WHERE agent_id IS NOT NULL")
  end

  def down
    execute("DROP INDEX quotes_unique_property_idx")
    execute("DROP INDEX quotes_unique_property_agents_idx")
  end
end

