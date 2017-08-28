class CreateEventsTracks < ActiveRecord::Migration
  def change
    create_table :events_tracks do |t|
      t.integer :type_of_tracking
      t.integer :buyer_id
      t.integer :agent_id
      t.integer :vendor_id
      t.integer :udprn
      t.integer :property_status_type, :default => 1
      t.string :hash_str
      t.boolean :active, default: true
      t.timestamps null: false
    end
  end
end
