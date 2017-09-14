class CreateSoldProperties < ActiveRecord::Migration
  def change
    create_table :sold_properties do |t|
      t.integer :udprn, null: false
      t.integer :sale_price, null: false
      t.date :completion_date
      t.integer :vendor_id, null: false
      t.integer :buyer_id, null: false
      t.integer :agent_id, null: false

      t.timestamps null: false
    end
    remove_column(:sold_properties, :updated_at)
  end
end
