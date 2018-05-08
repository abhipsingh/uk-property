class CreateLocationsStreets < ActiveRecord::Migration
  def change
    create_table :locations_streets do |t|
      t.integer :post_town_id
      t.string :name
      t.integer :locality_id
      t.integer :district_id
    end
  end
end
