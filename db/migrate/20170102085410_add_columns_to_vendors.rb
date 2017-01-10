class AddColumnsToVendors < ActiveRecord::Migration
  def change
    add_column :vendors, :provider, :string
    add_column :vendors, :uid, :string
  end
end
