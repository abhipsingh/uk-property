class AddRateToAddressDistrictregister < ActiveRecord::Migration
  def change
    add_column(:address_district_registers, :rate, :float)
  end
end

