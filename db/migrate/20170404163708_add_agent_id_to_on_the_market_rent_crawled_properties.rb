class AddAgentIdToOnTheMarketRentCrawledProperties < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties_rents, :agent_id, :integer)
  end
end
