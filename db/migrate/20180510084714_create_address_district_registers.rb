class CreateAddressDistrictRegisters < ActiveRecord::Migration
  def change
    create_table :address_district_registers do |t|
      t.integer :udprn
      t.string :district
      t.boolean :vendor_registered
      t.integer :vendor_id
      t.boolean :invite_sent

      t.timestamps null: false
    end

    add_index(:address_district_registers, :udprn, unique: true)
  end
end
