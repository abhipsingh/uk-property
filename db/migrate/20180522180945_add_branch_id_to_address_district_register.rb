class AddBranchIdToAddressDistrictRegister < ActiveRecord::Migration
  def change
    add_column(:address_district_registers, :branch_id, :integer)
  end
end

