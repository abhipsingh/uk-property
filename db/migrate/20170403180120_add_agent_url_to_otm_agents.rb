class AddAgentUrlToOtmAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_on_the_market_rents, :agent_url, :string)
  end
end
