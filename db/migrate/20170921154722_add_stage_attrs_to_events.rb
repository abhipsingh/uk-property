class AddStageAttrsToEvents < ActiveRecord::Migration
  def change
    add_column(:events, :scheduled_visit_time, :datetime)
    add_column(:events, :offer_price, :integer)
    add_column(:events, :offer_date, :date)
    add_column(:events, :expected_completion_date, :date)
  end
end
