class AddDiffEmailsToAgentsBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :sales_email, :string)
    add_column(:agents_branches, :commercial_email, :string)
    add_column(:agents_branches, :lettings_email, :string)
    add_column(:agents_branches, :suitable_for_launch, :boolean)
    add_column(:agents, :zoopla_company_id, :integer)
    add_column(:agents, :independent, :integer)
  end
end

