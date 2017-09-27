class AddStripeCustomerIdToAgents < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents, :stripe_customer_id, :string)
  end
end

