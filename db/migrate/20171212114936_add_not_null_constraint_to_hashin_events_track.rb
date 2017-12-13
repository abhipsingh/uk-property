class AddNotNullConstraintToHashinEventsTrack < ActiveRecord::Migration
  def change
    change_column(:events_tracks, :hash_str, :string, null: false)
  end
end
