class ModifyCountyInPropertyAddress < ActiveRecord::Migration
  def up
    execute("ALTER TABLE property_addresses ALTER COLUMN county TYPE uint1")
  end

  def down
    execute("ALTER TABLE property_addresses ALTER COLUMN county TYPE smallint")
  end
end

