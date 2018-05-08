class CreateLocationsUnits < ActiveRecord::Migration
  def change
    create_table :locations_units do |t|
      t.string :name
      t.integer :post_town_id
      t.integer :locality_id
      t.integer :street_id
    end
  end
end
