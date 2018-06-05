class CreateAgentCalendarUnavailabilities < ActiveRecord::Migration
  def change
    create_table :agent_calendar_unavailabilities do |t|
      t.datetime :start_time
      t.datetime :end_time

      t.timestamps null: false
    end
  end
end
