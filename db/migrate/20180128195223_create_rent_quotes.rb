class CreateRentQuotes < ActiveRecord::Migration
  def change
    create_table :rent_quotes do |t|
      t.integer :agent_id
      t.integer :udprn, null: false
      t.integer :vendor_id, null: false
      t.integer :price
      t.integer :payment_terms, null: false
      t.boolean :expired, default: false
      t.integer :parent_quote_id
      t.string  :district, null: false
      t.integer :status, null: false
      t.integer :existing_agent_id
      t.boolean :is_assigned_agent, default: false
      t.string  :terms_url
      t.timestamps null: false
    end
  end
end

