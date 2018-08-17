class AddBuyerIdToAgentAndVendorCalendar < ActiveRecord::Migration
  def change
    remove_column(:agent_calendar_unavailabilities, :vendor_id, :integer)
    remove_column(:vendor_calendar_unavailabilities, :agent_id, :integer)
    add_column(:agent_calendar_unavailabilities, :agent_id, :integer)
    add_column(:vendor_calendar_unavailabilities, :vendor_id, :integer)
    #add_column(:vendor_calendar_unavailabilities, :buyer_id, :integer)
  end
end
