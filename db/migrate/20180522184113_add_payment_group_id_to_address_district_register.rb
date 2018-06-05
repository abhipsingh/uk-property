class AddPaymentGroupIdToAddressDistrictRegister < ActiveRecord::Migration
  def change
    add_column(:address_district_registers, :payment_group_id, :integer)
  end
end

