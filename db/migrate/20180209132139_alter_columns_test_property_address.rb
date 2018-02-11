class AlterColumnsTestPropertyAddress < ActiveRecord::Migration
  def up
    execute("ALTER TABLE test_property_addresses ALTER COLUMN county TYPE uint1")
    execute("ALTER TABLE test_property_addresses ALTER COLUMN beds TYPE uint1")
    execute("ALTER TABLE test_property_addresses ALTER COLUMN baths TYPE uint1")
    execute("ALTER TABLE test_property_addresses ALTER COLUMN receptions TYPE uint1")
    execute("ALTER TABLE test_property_addresses ADD COLUMN property_type uint1")
    execute("ALTER TABLE test_property_addresses ALTER COLUMN pst TYPE uint1")
    execute("ALTER TABLE test_property_addresses ALTER COLUMN slu TYPE timestamp(0)")
  end

  def down
    execute("ALTER TABLE test_property_addresses DROPCOLUMN property_type")
  end
end
