class AddAgentIdToPropertyEvents < ActiveRecord::Migration
  def change
    add_column(:property_events, :agent_id, :integer)
    add_column(:property_events, :vendor_id, :integer)
  end
end
