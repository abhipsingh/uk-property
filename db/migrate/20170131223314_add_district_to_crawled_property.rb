class AddDistrictToCrawledProperty < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties, :district, :string)
  end
end
