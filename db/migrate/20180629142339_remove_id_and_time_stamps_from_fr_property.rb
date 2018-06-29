class RemoveIdAndTimeStampsFromFrProperty < ActiveRecord::Migration
  def change
    remove_column(:fr_properties, :created_at, :timestamp)
    remove_column(:fr_properties, :updated_at, :timestamp)
    remove_column(:fr_properties, :id, :integer)
  end
end
