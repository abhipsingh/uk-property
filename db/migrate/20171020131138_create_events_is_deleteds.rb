class CreateEventsIsDeleteds < ActiveRecord::Migration
  def change
    create_table :events_is_deleteds do |t|
      t.integer :agent_id
      t.integer :udprn
      t.integer :vendor_id
      t.integer :buyer_id
      t.timestamp :created_at, null: false
    end
  end
end
