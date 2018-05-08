class CreateLocationsPostTowns < ActiveRecord::Migration
  def change
    create_table :locations_post_towns do |t|
      t.integer :county_id, limit: 2
      t.string :name
    end
  end
end
