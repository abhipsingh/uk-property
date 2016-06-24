class AddMissingDetailToPropertyUserAndTempPropertyDetail < ActiveRecord::Migration
  def change
    add_column(:property_users, :first_name, :string)
    add_column(:property_users, :last_name, :string)
    add_column(:property_users, :profile_type, :string)
    add_column(:temp_property_details, :vendor_id, :integer)
    add_column(:temp_property_details, :agent_id, :integer)
  end
end
