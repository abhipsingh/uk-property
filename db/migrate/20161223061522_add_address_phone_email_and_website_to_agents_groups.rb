class AddAddressPhoneEmailAndWebsiteToAgentsGroups < ActiveRecord::Migration
  def change
    add_column(:agents_groups, :website, :string)
    add_column(:agents_groups, :email, :string)
    add_column(:agents_groups, :phone_number, :string)
    add_column(:agents_groups, :address, :string)
  end
end
