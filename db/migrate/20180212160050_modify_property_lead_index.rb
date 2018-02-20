class ModifyPropertyLeadIndex < ActiveRecord::Migration
  def up
    execute("DROP INDEX unique_vendor_property_claims_non_expired")
    execute("CREATE UNIQUE INDEX unique_vendor_property_claims_non_expired ON agents_branches_assigned_agents_leads(property_id) WHERE expired ='f'")
  end

  def down
    execute("DROP INDEX unique_vendor_property_claims_non_expired")
    execute("CREATE INDEX unique_vendor_property_claims_non_expired ON agents_branches_assigned_agents_leads(property_id) WHERE expired ='f'")
  end
end

