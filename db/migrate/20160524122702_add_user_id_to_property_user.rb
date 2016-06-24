class AddUserIdToPropertyUser < ActiveRecord::Migration
  def change
    add_column(:temp_property_details, :user_id, :integer)
    add_index(:temp_property_details, :user_id)
  end
end
