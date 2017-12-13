class AddExpiredToQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :expired, :boolean, default: false)
    execute("DROP INDEX quotes_unique_property_agents_idx")
    execute("CREATE UNIQUE INDEX quotes_unique_property_agents_idx ON agents_branches_assigned_agents_quotes(agent_id, property_id, expired) WHERE agent_id IS NOT NULL")
  end
end

