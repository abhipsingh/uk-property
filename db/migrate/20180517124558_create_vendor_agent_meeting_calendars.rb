class CreateVendorAgentMeetingCalendars < ActiveRecord::Migration
  def change
    create_table :vendor_agent_meeting_calendars do |t|
      t.integer :agent_id
      t.integer :vendor_id
      t.datetime :start_time
      t.datetime :end_time

      t.timestamps null: false
    end
  end
end
