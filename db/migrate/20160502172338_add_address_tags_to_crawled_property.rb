class AddAddressTagsToCrawledProperty < ActiveRecord::Migration
  def change
    add_column :agents_branches_crawled_properties, :tags, :string, array: true, default: []
#    add_index :agents_branches_crawled_properties, :tags, using: 'gin'
  end
end
