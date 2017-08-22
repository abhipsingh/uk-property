class AddEmailSuffixesToAgentsBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :rent_email_suffix, :string)
    add_column(:agents_branches, :buy_email_suffix, :string)
  end
end
