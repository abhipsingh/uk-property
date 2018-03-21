class AddStatusToSoldProperty < ActiveRecord::Migration
  def change
    add_column(:sold_properties, :status, :boolean, default: false)
  end
end

