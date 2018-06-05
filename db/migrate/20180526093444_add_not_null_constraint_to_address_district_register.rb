class AddNotNullConstraintToAddressDistrictRegister < ActiveRecord::Migration
  def change
    change_column(:address_district_registers, :payment_group_id, :integer, null: false)
  end
end
