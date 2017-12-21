class CreateFieldValueStores < ActiveRecord::Migration
  def change
    create_table :field_value_stores do |t|
      t.integer :field_type
      t.string :name
      t.timestamp :created_at, null: false
    end
  end
end

