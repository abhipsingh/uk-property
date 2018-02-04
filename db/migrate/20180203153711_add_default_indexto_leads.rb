class AddDefaultIndextoLeads < ActiveRecord::Migration
  def up
    execute("CREATE INDEX unique_vendor_property_claims_non_expired ON agents_branches_assigned_agents_leads(property_id) WHERE expired ='f'")
    execute("DROP INDEX unique_vendor_property_claims ")
  end

  def down
    execute("DROP INDEX unique_vendor_property_claims_non_expired")
    execute("CREATE INDEX unique_vendor_property_claims ON agents_branches_assigned_agents_leads(property_id)")
  end
end
