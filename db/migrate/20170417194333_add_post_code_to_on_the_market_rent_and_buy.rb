class AddPostCodeToOnTheMarketRentAndBuy < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties_rents, :postcode, :string)
    add_column(:agents_branches_crawled_properties_buys, :postcode, :string)
  end
end
