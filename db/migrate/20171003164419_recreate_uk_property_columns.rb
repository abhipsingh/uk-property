class RecreateUkPropertyColumns < ActiveRecord::Migration
  def change
    drop_table(:uk_properties)

    create_table :uk_properties do |t|
      t.string :post_town, limit: 25
      t.string :county, limit: 20
      t.string :postcode, limit: 8
      t.string :dl
      t.string :ddl
      t.string :td
      t.string :dtd
      t.string :building_name
      t.string :building_number, limit: 10
      t.string :sub_building_name
      t.string :department_name
      t.string :organisation_name
      t.integer :udprn
      t.string :postcode_type, limit: 2
      t.string :su_organisation_indicator, limit: 3
      t.string :delivery_point_suffix, limit: 3
      t.boolean :indexed
      t.timestamps null: false
    end

  end
end
