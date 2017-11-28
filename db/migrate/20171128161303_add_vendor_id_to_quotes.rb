class AddVendorIdToQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :vendor_id, :integer)
  end
end

