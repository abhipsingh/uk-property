class AddIsDeletedToEvents < ActiveRecord::Migration
  def change
    add_column :events, :is_deleted, :boolean, default: false
  end
end
