class AddIndexToNameInFieldValueStore < ActiveRecord::Migration
  def up
    execute("CREATE INDEX field_value_stores_names_idx ON field_value_stores (name text_pattern_ops)")
  end

  def down
    execute("DROP INDEX field_value_stores_names_idx ")
  end
end

