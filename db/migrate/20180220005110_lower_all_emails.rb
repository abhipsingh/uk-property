class LowerAllEmails < ActiveRecord::Migration
  def change
    execute("UPDATE agents_branches_assigned_agents SET email=lower(email);")
    execute("UPDATE vendors SET email=lower(email);")
    execute("UPDATE property_buyers SET email=lower(email);")
  end
end
