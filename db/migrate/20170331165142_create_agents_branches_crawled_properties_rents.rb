class CreateAgentsBranchesCrawledPropertiesRents < ActiveRecord::Migration
  def change
    create_table :agents_branches_crawled_properties_rents do |t|
      t.string :price
      t.string :locality
      t.string :description
      t.text :image_urls, array: true, default: []
      t.string :agent_url
      t.float :latitude
      t.float :longitude

      t.timestamps null: false
    end
  end
end
