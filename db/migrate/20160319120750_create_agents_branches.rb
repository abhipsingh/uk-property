class CreateAgentsBranches < ActiveRecord::Migration
  def change
    create_table :agents_branches do |t|
      t.string :name
      t.string :property_urls
      t.integer :agent_id
      t.string :address
    end
  end
end
