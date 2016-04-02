class AddUdprnToPropertyHistoricalDetail < ActiveRecord::Migration
  def change
    add_column(:property_historical_details, :udprn, :string)
  end
end
