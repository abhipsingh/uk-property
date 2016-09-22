class AddStatusIdToPropertyBuyer < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :status_id, :integer)
  end
end
