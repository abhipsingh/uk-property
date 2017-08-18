class ModifyBiggestProblemsToJsonb < ActiveRecord::Migration
  def change
    remove_column(:property_buyers, :biggest_problems, :jsonb)
    add_column(:property_buyers, :biggest_problems, :jsonb)
  end
end
