class RemoveIdFromPropertyAddress < ActiveRecord::Migration
  def up
    remove_column(:property_addresses, :id)
  end

  def down
    add_column(:property_addresses, :id, :integer, unique: true)
  end
end

