class AddUniqueIndexToAgentsQuotesActiveProperty < ActiveRecord::Migration
  def up
    new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    execute("CREATE UNIQUE INDEX agent_unique_quotes_active_property_idx ON agents_branches_assigned_agents_quotes(agent_id, property_id) WHERE parent_quote_id IS NOT NULL AND status = #{new_status} AND expired = 'f' ")
    execute("CREATE UNIQUE INDEX vendor_quote_active_property_idx ON agents_branches_assigned_agents_quotes(property_id) WHERE parent_quote_id IS NULL AND status = #{new_status} AND expired='f'")
  end

  def down
    execute("DROP INDEX agent_unique_quotes_active_property_idx ")
    execute("DROP INDEX vendor_quote_active_property_idx ")
  end
end
