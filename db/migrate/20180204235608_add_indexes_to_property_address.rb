class AddIndexesToPropertyAddress < ActiveRecord::Migration
  def up
    execute(" CREATE INDEX address_search_idx ON property_addresses(pt, dl, td, dtd)")
    execute(" CREATE INDEX postcode_suggest_idx ON property_addresses USING GIN(to_tsvector('simple'::regconfig, postcode::text))")
  end

  def down
    execute(" DROP INDEX address_search_idx")
    execute("DROP INDEX postcode_suggest_idx")
  end
end

