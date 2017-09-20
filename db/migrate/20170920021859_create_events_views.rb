class CreateEventsViews < ActiveRecord::Migration
  def change
    create_table :events_views do |t|
      t.integer :udprn, null: false
      t.integer :buyer_id, null: false
      t.integer :agent_id
      t.integer :vendor_id
      t.integer :service
      t.timestamp :created_at, null: false
    end
  end
end
