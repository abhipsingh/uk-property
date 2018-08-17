class AddIndexesToRentQuotes < ActiveRecord::Migration
  def up
    execute("CREATE UNIQUE INDEX rent_agent_unique_quotes_active_property_idx ON rent_quotes(agent_id, udprn) WHERE parent_quote_id IS NOT NULL AND status = 1 AND expired = false")
    execute("CREATE UNIQUE INDEX rent_vendor_quote_active_property_idx ON rent_quotes(udprn) WHERE parent_quote_id IS NULL AND status = 1 AND expired = false")
    execute("CREATE INDEX  rent_quotes_district_idx ON rent_quotes(district)")
  end

  def down
    execute("DROP INDEX rent_agent_unique_quotes_active_property_idx")
    execute("DROP INDEX rent_vendor_quote_active_property_idx")
    execute("DROP INDEX rent_quotes_district_idx")
  end
end

