class AddUniqueIndexForVendorProperty < ActiveRecord::Migration
  def change
    add_index(:agents_branches_assigned_agents_leads, [:property_id], unique: true, name: 'unique_vendor_property_claims' )
  end
end
