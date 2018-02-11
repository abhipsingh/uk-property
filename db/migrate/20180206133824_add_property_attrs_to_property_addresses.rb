class AddPropertyAttrsToPropertyAddresses < ActiveRecord::Migration
  def up
    execute("ALTER TABLE property_addresses ADD COLUMN beds uint1")
    execute("ALTER TABLE property_addresses ADD COLUMN baths uint1")
    execute("ALTER TABLE property_addresses ADD COLUMN receptions uint1")
    execute("ALTER TABLE property_addresses ADD COLUMN property_type uint1")
    execute("ALTER TABLE property_addresses ADD COLUMN property_status_type uint1")
    execute("ALTER TABLE property_addresses ADD COLUMN status_last_updated timestamp(0)")
  end

  def down
    execute("ALTER TABLE property_addresses DROP COLUMN beds")
    execute("ALTER TABLE property_addresses DROP COLUMN baths")
    execute("ALTER TABLE property_addresses DROP COLUMN receptions")
    execute("ALTER TABLE property_addresses DROP COLUMN property_type")
    execute("ALTER TABLE property_addresses DROP COLUMN property_status_type")
    execute("ALTER TABLE property_addresses DROP COLUMN status_last_updated")
  end
end

