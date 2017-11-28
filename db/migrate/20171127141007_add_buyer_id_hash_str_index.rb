class AddBuyerIdHashStrIndex < ActiveRecord::Migration
  def change
    add_index(:events_tracks, [:buyer_id, :hash_str], unique: true)
  end
end

