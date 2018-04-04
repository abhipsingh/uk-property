class ChangeBuyerStatusChangePrevStatusToDefaultNotNull < ActiveRecord::Migration
  def change
    remove_column(:buyer_status_changes, :prev_status)
    add_column(:buyer_status_changes, :prev_status, :integer, limit: 2)
  end
end
