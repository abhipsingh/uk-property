class AddDistrictToQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :district, :string)
    add_index(:agents_branches_assigned_agents_quotes, :district)
  end
end
