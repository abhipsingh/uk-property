class AddUdprnToTestPropertyAddress < ActiveRecord::Migration
  def change
    add_column(:test_property_addresses, :udprn, :integer)
  end
end

