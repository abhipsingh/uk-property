class AddBuyerNameEmailMobileAndAddressToQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :vendor_name, :string)
    add_column(:agents_branches_assigned_agents_quotes, :vendor_email, :string)
    add_column(:agents_branches_assigned_agents_quotes, :vendor_mobile, :string)
    add_column(:agents_branches_assigned_agents_quotes, :address, :string)
  end
end
