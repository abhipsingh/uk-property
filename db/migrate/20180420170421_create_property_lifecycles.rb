class CreatePropertyLifecycles < ActiveRecord::Migration
  def change
    create_table :property_lifecycles do |t|
      t.integer :udprn, null: false
      t.timestamp :created_at, null: false
      t.timestamp :completed_at
    end
  end
end

