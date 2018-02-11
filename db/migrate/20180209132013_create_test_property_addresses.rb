class CreateTestPropertyAddresses < ActiveRecord::Migration
  def change
    create_table :test_property_addresses do |t|
      t.string :postcode, limit: 7
      t.integer :pt, limit: 2
      t.integer :county
      t.string :dl
      t.string :td
      t.string :dtd
      t.integer :beds
      t.integer :baths
      t.integer :receptions
      t.integer :pst
      t.integer :pt
      t.timestamp :slu
    end
  end
end
