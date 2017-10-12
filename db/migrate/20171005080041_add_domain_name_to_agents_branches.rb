class AddDomainNameToAgentsBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :domain_name, :string)
  end
end

