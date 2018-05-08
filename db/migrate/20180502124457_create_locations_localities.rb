class CreateLocationsLocalities < ActiveRecord::Migration
  def change
    create_table :locations_localities do |t|
      t.integer :post_town_id
      t.integer :district_id
      t.string :name
    end
  end
end
