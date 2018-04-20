class AddLifecylceCounterToPropertyEvent < ActiveRecord::Migration
  def change
    add_column(:property_events, :lifecycle_count, :integer, default: 0, limit: 2)
  end
end
