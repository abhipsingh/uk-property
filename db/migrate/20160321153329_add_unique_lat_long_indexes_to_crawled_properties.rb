class AddUniqueLatLongIndexesToCrawledProperties < ActiveRecord::Migration
  def change
    add_column :agents_branches_crawled_properties, :latitude, :decimal
    add_column :agents_branches_crawled_properties, :longitude, :decimal
    add_index :agents_branches_crawled_properties, [:latitude, :longitude], :unique => true, name: 'uniq_property'

  end
end
