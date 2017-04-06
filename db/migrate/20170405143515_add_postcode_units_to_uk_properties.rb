class AddPostcodeUnitsToUkProperties < ActiveRecord::Migration
  def change
    add_column(:uk_properties, :building_text, :string)
    add_column(:uk_properties, :area, :string)
    add_column(:uk_properties, :district, :string)
    add_column(:uk_properties, :sector, :string)
    add_column(:uk_properties, :unit, :string)
    add_column(:uk_properties, :county, :string)
  end
end
