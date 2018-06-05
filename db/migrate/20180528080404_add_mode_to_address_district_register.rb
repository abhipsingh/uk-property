class AddModeToAddressDistrictRegister < ActiveRecord::Migration
  def change
    add_column(:address_district_registers, :mode, :integer, limit: 2)
  end
end

