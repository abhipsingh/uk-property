class CreatePropertyEvents < ActiveRecord::Migration
  def change
    create_table :property_events do |t|
      t.jsonb :attr_hash, default: '{}', null: false
      t.integer :udprn, null: false
      t.timestamp :created_at, null: false
    end
  end
end
