class CreateBuyerSearches < ActiveRecord::Migration
  def change
    create_table :buyer_searches do |t|
      t.integer :buyer_id
      t.jsonb :search_hash
      t.integer :match_type
      t.integer :listing_type
      t.timestamps null: false
    end
  end
end
