class CreateLocationsCounties < ActiveRecord::Migration
  def change
    create_table :locations_counties do |t|
      t.string :name
    end
  end
end
