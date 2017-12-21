class AddDeveloperIdToInvitedDevelopers < ActiveRecord::Migration
  def change
    add_column(:invited_developers, :branch_id, :integer)
  end
end

