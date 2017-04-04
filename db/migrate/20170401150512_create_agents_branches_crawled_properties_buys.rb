class CreateAgentsBranchesCrawledPropertiesBuys < ActiveRecord::Migration
  def change
    create_table :agents_branches_crawled_properties_buys do |t|
      t.string :price
      t.string :description
      t.string :locality
      t.string :agent_url
      t.float :latitude
      t.float :longitude
      t.text :image_urls, array: true, default: []
      t.text :floorplan_urls, array: true, default: []

      t.timestamps null: false
    end
  end
end
