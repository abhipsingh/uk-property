class AddImageUrlsToCrawledProperties < ActiveRecord::Migration
  def change
    add_column(:agents_branches_crawled_properties, :image_urls, :text, { array: true, default: [] })
  end
end
