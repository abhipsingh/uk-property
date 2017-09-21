class AddStageAndRatingToEvent < ActiveRecord::Migration
  def change
    add_column(:events, :stage, :integer, limit: 2, default: 15)
    add_column(:events, :rating, :integer, limit: 2, default: 29)
    change_column(:events, :event, :integer, limit: 2)
  end
end
