class AddIsArchivedToEvents < ActiveRecord::Migration
  def change
    add_column(:events, :is_archived, :boolean, default: false)
  end
end
