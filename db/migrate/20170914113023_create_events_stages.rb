class CreateEventsStages < ActiveRecord::Migration
  def change
    create_table :events_stages do |t|
      t.integer :event
      t.integer :buyer_id
      t.integer :agent_id
      t.integer :property_status_type
      t.jsonb :message

      t.timestamps null: false
    end
    remove_column(:events_stages, :updated_at)
    remove_column(:events_tracks, :vendor_id)
  end
end
