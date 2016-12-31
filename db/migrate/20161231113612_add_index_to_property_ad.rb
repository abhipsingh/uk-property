class AddIndexToPropertyAd < ActiveRecord::Migration
  def change
    add_index(:property_ads, [:property_id, :ad_type, :hash_str], unique: true)
  end
end
