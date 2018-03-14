class DropIndexesFromQuotes < ActiveRecord::Migration
  def change
    execute('DROP INDEX quotes_unique_property_idx')
    execute('DROP INDEX quotes_unique_property_agents_idx')
  end
end
