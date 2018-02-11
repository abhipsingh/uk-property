class AddDistrictAndSectorToPropertyAddress < ActiveRecord::Migration
  def change
    add_column(:property_addresses, :district, :string, limit: 4)
    add_column(:property_addresses, :sector, :string, limit: 6)
  end
end

