class AddExpiredIndexUniquePropertiesIndexToQuotes < ActiveRecord::Migration
  def change
    execute("DROP INDEX quotes_unique_property_idx")
    execute("CREATE UNIQUE INDEX quotes_unique_property_idx ON agents_branches_assigned_agents_quotes(property_id, expired) WHERE agent_id IS NULL and expired ='f'")
  end
end
