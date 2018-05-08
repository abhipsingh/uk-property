class CreateLocationsSectors < ActiveRecord::Migration
  def change
    create_table :locations_sectors do |t|
      t.string :name
      t.integer :post_town_id
      t.integer :locality_id
    end
  end
end
