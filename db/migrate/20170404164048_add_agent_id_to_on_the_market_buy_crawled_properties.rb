class AddAgentIdToOnTheMarketBuyCrawledProperties < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties_buys, :agent_id, :integer)
  end
end
