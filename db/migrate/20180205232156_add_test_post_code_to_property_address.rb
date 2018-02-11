class AddTestPostCodeToPropertyAddress < ActiveRecord::Migration
  def change
    add_column(:property_addresses, :test_postcode, :string, limit: 7)
  end
end
