class AddIndexToPaymentGroupIdInAddressesDistrictRegsiter < ActiveRecord::Migration
  def up
    execute("CREATE INDEX processed_preassigned_prop ON address_district_registers(processed) WHERE processed='f'")
  end

  def down
    execute("DROP INDEX processed_preassigned_prop")
  end
end

