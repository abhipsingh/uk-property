class CreateBuyerStatusChanges < ActiveRecord::Migration
  def change
    create_table :buyer_status_changes do |t|
      t.integer :buyer_id, null: false
      t.date :date, null: false
      t.integer :prev_status, limit: 2, null: false
      t.integer :new_status, limit: 2, null: false
    end
  end
end
