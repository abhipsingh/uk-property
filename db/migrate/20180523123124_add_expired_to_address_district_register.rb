class AddExpiredToAddressDistrictRegister < ActiveRecord::Migration
  def change
    add_column(:address_district_registers, :expired, :boolean, default: false)
    add_index(:address_district_registers, :branch_id)
    execute("CREATE UNIQUE INDEX preassigned_addr_non_exp_uniq_prop ON address_district_registers(branch_id, udprn) WHERE expired='f'")
  end
end

