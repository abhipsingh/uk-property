class CreateVendorCalendarUnavailabilities < ActiveRecord::Migration
  def change
    create_table :vendor_calendar_unavailabilities do |t|
      t.datetime :start_time
      t.datetime :end_time

      t.timestamps null: false
    end
  end
end
