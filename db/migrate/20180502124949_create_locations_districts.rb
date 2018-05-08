class CreateLocationsDistricts < ActiveRecord::Migration
  def change
    create_table :locations_districts do |t|
      t.string :name
      t.integer :post_town_id
    end
  end
end
