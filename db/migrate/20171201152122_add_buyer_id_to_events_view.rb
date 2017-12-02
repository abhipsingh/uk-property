class AddBuyerIdToEventsView < ActiveRecord::Migration
  def change
    add_column(:events_views, :buyer_id, :integer)
  end
end

