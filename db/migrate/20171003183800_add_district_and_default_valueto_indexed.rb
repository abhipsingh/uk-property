class AddDistrictAndDefaultValuetoIndexed < ActiveRecord::Migration
  def change
    add_column(:uk_properties, :district, :string, limit: 5)
    change_column(:uk_properties, :indexed, :boolean, default: false)
    add_index(:uk_properties, :postcode)
    add_index(:uk_properties, :udprn)
    add_index(:uk_properties, :district)
  end
end
