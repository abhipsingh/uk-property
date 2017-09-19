class AddUdprnToEventsStage < ActiveRecord::Migration
  def change
    add_column(:events_stages, :udprn, :integer)
  end
end
