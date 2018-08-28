class AddEventIdToAgentCalendarUnavailablity < ActiveRecord::Migration
  def change
    add_column(:agent_calendar_unavailabilities, :event_id, :integer)
  end
end
