class RemoveUpdatedAtFromAgrentPremptions < ActiveRecord::Migration
  def change
    remove_column(:address_district_registers, :updated_at, :datetime)
    add_column(:address_district_registers, :vendor_claimed_at, :datetime)
  end
end

