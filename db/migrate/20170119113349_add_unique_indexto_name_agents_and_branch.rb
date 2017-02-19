class AddUniqueIndextoNameAgentsAndBranch < ActiveRecord::Migration
  def change
    add_index(:agents, [:name, :branches_url], {unique: true})
    add_index(:agents_branches, [:name, :district, :property_urls]  , {unique: true})
  end
end
