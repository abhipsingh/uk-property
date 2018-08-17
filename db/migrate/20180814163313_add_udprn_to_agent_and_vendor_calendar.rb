class AddUdprnToAgentAndVendorCalendar < ActiveRecord::Migration
  def change
    add_column(:agent_calendar_unavailabilities, :udprn, :integer)
    add_column(:vendor_calendar_unavailabilities, :udprn, :integer)
    add_column(:agent_calendar_unavailabilities, :buyer_id, :integer)
    add_column(:vendor_calendar_unavailabilities, :buyer_id, :integer)
    add_column(:agent_calendar_unavailabilities, :vendor_id, :integer)
    add_column(:vendor_calendar_unavailabilities, :agent_id, :integer)
  end
end

