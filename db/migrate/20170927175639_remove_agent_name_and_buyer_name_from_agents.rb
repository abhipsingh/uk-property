class RemoveAgentNameAndBuyerNameFromAgents < ActiveRecord::Migration
  def change
    remove_column(:events, :buyer_name)
    remove_column(:events, :agent_name)
  end
end
