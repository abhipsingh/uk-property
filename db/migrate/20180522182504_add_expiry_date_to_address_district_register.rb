class AddExpiryDateToAddressDistrictRegister < ActiveRecord::Migration
  def change
    add_column(:address_district_registers, :expiry_date, :date)
  end
end

