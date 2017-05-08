class AddUniqueIndexToVendorProperty < ActiveRecord::Migration
  def change
    add_index(:vendors, :property_id, unique: true)
  end
end
