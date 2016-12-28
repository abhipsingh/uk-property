class AddPasswordDigestToAgenntsAndPropertyBuyers < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :password_digest, :string)
    add_column(:agents_branches_assigned_agents, :password_digest, :string)
  end
end
