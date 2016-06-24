class AddProviderAndUidToPropertyUser < ActiveRecord::Migration
  def change
    add_column :property_users, :provider, :string
    add_index :property_users, :provider
    add_column :property_users, :uid, :string
    add_index :property_users, :uid
  end
end
