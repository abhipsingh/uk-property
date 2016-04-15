class AddIndexToUdprnInPropertyHistoricalDetails < ActiveRecord::Migration
  def change
    add_index :property_historical_details, :udprn
  end
end
