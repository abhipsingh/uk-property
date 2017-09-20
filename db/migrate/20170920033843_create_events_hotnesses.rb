class CreateEventsHotnesses < ActiveRecord::Migration
  def change
    create_table :events_hotnesses do |t|
      t.integer :event
      t.integer :udprn
      t.integer :buyer_id
      t.integer :agent_id
      t.integer :service

      t.timestamps null: false
    end
  end
end
