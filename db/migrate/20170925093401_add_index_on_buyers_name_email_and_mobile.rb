class AddIndexOnBuyersNameEmailAndMobile < ActiveRecord::Migration
  def up
    execute("CREATE INDEX buyers_name_mobile_idx ON property_buyers USING GIN (to_tsvector('simple', ( name || ' ' || mobile)))")
  end

  def down
    execute("DROP INDEX buyers_name_mobile_idx")
  end
end

