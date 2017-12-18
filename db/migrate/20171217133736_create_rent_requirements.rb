class CreateRentRequirements < ActiveRecord::Migration
  def change
    create_table :rent_requirements do |t|
      t.integer :min_beds
      t.integer :max_beds
      t.integer :min_baths
      t.integer :max_baths
      t.integer :max_receptions
      t.integer :min_receptions
      t.integer :buyer_id
      t.jsonb :locations
      t.timestamp :created_at, null: false
    end
  end
end

