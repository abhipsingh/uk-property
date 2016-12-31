class CreatePropertyAds < ActiveRecord::Migration
  def change
    create_table :property_ads do |t|
      t.integer :property_id
      t.string :hash_str
      t.integer :ad_type

      t.timestamps null: false
    end
  end
end
