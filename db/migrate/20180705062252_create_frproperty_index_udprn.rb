class CreateFrpropertyIndexUdprn < ActiveRecord::Migration
  def up
    execute("CREATE INDEX fr_addresses_search_idx ON fr_properties(county, pt, md5(dl), md5(dtd), udprn)")
  end

  def down
    execute("DROP INDEX fr_addresses_search_idx")
  end
end

