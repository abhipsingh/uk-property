class AddMonthsToAddressDistrictRegister < ActiveRecord::Migration
  def change
    add_column(:address_district_registers, :months, :integer)
  end
end

