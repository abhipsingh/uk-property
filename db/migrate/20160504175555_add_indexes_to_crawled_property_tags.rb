class AddIndexesToCrawledPropertyTags < ActiveRecord::Migration
  def change
    add_index(:agents_branches_crawled_properties, :tags, using: 'gin')
  end
end
