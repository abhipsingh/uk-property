class DropIsDeletedFromEvents < ActiveRecord::Migration
  def change
    remove_column(:events, :is_deleted)
  end
end
