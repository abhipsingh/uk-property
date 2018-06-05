class RemoveModeAndMonthsFromAddressDistrictRegisters < ActiveRecord::Migration
  def change
    remove_column(:address_district_registers, :mode)
    remove_column(:address_district_registers, :months)
  end

end

