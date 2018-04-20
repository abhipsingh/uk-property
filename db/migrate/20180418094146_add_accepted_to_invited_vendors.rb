class AddAcceptedToInvitedVendors < ActiveRecord::Migration
  def change
    add_column(:invited_vendors, :accepted, :boolean)
  end
end

