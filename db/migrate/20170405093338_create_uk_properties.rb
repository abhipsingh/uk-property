class CreateUkProperties < ActiveRecord::Migration
  def change
    create_table :uk_properties do |t|
      t.string :post_code
      t.string :post_town
      t.string :dependent_locality
      t.string :double_dependent_locality
      t.string :thoroughfare_descriptor
      t.string :dependent_thoroughfare_description
      t.string :building_number
      t.string :building_name
      t.string :sub_building_name
      t.string :po_box_no
      t.string :department_name
      t.string :organization_name
      t.integer :udprn
      t.string :postcode_type
      t.string :su_organisation_indicator
      t.string :delivery_point_suffix
    end
  end
end
