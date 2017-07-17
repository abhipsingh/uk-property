class AddServiceToPropertyAd < ActiveRecord::Migration
  def change
    add_column(:property_ads, :service, :integer)
  end
end
