class AddUniqueIndexToAgentsName < ActiveRecord::Migration
  def change
    add_index(:agents_branches_on_the_market_rents, :name, { unique: true })
  end
end
