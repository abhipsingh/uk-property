class CreateAgentsBranchesOnTheMarketRents < ActiveRecord::Migration
  def change
    create_table :agents_branches_on_the_market_rents do |t|
      t.string :name
      t.string :address
      t.string :phone
      t.string :image_url

      t.timestamps null: false
    end
  end
end
