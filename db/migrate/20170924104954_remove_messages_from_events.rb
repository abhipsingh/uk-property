class RemoveMessagesFromEvents < ActiveRecord::Migration
  def change
    remove_column(:events, :message)
  end
end
