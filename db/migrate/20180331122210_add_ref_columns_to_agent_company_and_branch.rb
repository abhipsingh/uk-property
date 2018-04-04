class AddRefColumnsToAgentCompanyAndBranch < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :prophety_branch_id, :integer)
    #add_column(:agents, :zoopla_company_id, :integer)
    add_column(:agents, :prophety_company_id, :integer)
  end
end
