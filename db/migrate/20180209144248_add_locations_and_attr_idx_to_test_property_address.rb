class AddLocationsAndAttrIdxToTestPropertyAddress < ActiveRecord::Migration
  def up
    execute(" CREATE INDEX test_address_search_not_null_idx ON test_property_addresses(pt, dl, td, dtd, beds, baths, receptions, property_type, pst) where beds is not null")
    execute(" CREATE INDEX test_address_search_idx ON test_property_addresses(pt, dl, td, dtd)")
    execute(" CREATE INDEX test_postcode_suggest_idx ON test_property_addresses USING GIN(to_tsvector('simple'::regconfig, postcode::text))")
  end

  def down
    execute(" DROP INDEX test_address_search_idx ")
    execute(" DROP INDEX test_postcode_suggest_idx ")
    execute(" DROP INDEX test_address_search_not_null_idx ")
  end
end
