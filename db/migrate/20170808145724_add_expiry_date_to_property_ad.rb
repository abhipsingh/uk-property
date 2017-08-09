class AddExpiryDateToPropertyAd < ActiveRecord::Migration
  def change
    add_column(:property_ads, :expiry_at, :datetime)
  end
end
