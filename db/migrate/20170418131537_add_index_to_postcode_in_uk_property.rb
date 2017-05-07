class AddIndexToPostcodeInUkProperty < ActiveRecord::Migration
  def change
    execute("CREATE INDEX trgm_postcode_indx ON uk_properties USING gist (post_code gist_trgm_ops);")
  end
end
