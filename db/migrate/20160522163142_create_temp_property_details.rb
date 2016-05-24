class CreateTempPropertyDetails < ActiveRecord::Migration
  def change
    create_table :temp_property_details do |t|
      t.jsonb :details
      t.string :session_id
      t.string :udprn

      t.timestamps null: false
    end
  end
end
