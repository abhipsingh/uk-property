class RemoveAttrsFromEventsView < ActiveRecord::Migration
  def change
    remove_column(:events_views, :created_at)
    remove_column(:events_views, :buyer_id)
    remove_column(:events_views, :vendor_id)
    remove_column(:events_views, :service)
    remove_column(:events_views, :agent_id)
    add_column(:events_views, :month, :integer)
  end
end

