class AddNewColumnsToVendors < ActiveRecord::Migration
  def change
    add_column :vendors, :oauth_token, :string
    add_column :vendors, :oauth_expires_at, :datetime
  end
end
