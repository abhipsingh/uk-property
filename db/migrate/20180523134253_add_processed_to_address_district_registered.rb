class AddProcessedToAddressDistrictRegistered < ActiveRecord::Migration
  def up
    add_column(:address_district_registers, :processed, :boolean, default: false)
  end

  def down
    remove_column(:address_district_registers, :processed)
  end
end

