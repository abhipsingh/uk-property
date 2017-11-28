class AddNotNullConstraintToVendorIdInQuotes < ActiveRecord::Migration
  def change
    change_column(:agents_branches_assigned_agents_quotes, :vendor_id, :integer, null: false)
  end
end

