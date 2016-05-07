class CreatePropertyBuyers < ActiveRecord::Migration
  def change
    create_table :property_buyers do |t|
      t.jsonb :searches, null: false, default: '[]'
      t.string :name, null: false
      t.string :email_id, null: false
      t.string :account_type, null: false
      t.jsonb :visited_udprns, null: false, default: '[]'
      t.timestamps null: false
    end

    add_index :property_buyers, [:email_id], unique: true
  end
end
