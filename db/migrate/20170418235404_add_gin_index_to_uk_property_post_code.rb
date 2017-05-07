class AddGinIndexToUkPropertyPostCode < ActiveRecord::Migration
  def change
    execute("create index on uk_properties using gin(to_tsvector('english', post_code));")
  end
end
