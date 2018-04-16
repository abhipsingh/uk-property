class AddRegisteredToInvitedVendor < ActiveRecord::Migration
  def change
    add_column(:invited_vendors, :registered, :boolean, default: false)
  end
end

