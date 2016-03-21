class CreateAgentsBranchesCrawledProperties < ActiveRecord::Migration
  def change
    create_table :agents_branches_crawled_properties do |t|
      t.text :html
      t.jsonb :stored_response
      t.integer :branch_id
      t.timestamps
    end
  end
end
