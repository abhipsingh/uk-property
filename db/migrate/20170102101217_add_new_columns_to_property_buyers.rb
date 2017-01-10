class AddNewColumnsToPropertyBuyers < ActiveRecord::Migration
  def change
    add_column :property_buyers, :oauth_token, :string
    add_column :property_buyers, :oauth_expires_at, :datetime
  end
end
