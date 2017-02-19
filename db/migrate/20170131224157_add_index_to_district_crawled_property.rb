class AddIndexToDistrictCrawledProperty < ActiveRecord::Migration
  def change
    add_index(:agents_branches_crawled_properties, :district)
  end
end
