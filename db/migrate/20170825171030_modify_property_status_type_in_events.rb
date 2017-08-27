class ModifyPropertyStatusTypeInEvents < ActiveRecord::Migration
  def change
    remove_column(:events, :property_status_type)
    add_column(:events, :property_status_type, :integer, default: 0)
  end
end
