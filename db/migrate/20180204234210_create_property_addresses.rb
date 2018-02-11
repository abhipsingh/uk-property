class CreatePropertyAddresses < ActiveRecord::Migration
  def change
    create_table :property_addresses do |t|
      t.integer :udprn
      t.integer :pt, limit: 2
      t.integer :county
      t.string :postcode, limit: 7
      t.string :dl
      t.string :td
      t.string :dtd
    end
  end
end

