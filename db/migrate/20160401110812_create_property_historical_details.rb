class CreatePropertyHistoricalDetails < ActiveRecord::Migration
  def change
    create_table :property_historical_details do |t|
      t.string :uuid
      t.integer :price
      t.string :date
    end
  end
end
