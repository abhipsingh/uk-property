class AddScheduledVisitEndTimeToEvents < ActiveRecord::Migration
  def change
    add_column(:events, :scheduled_visit_end_time, :timestamp)
  end
end
