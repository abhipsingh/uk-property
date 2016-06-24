class AddAddressToAgentsBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :postcode, :string)
    add_column(:agents_branches, :district, :string)
    add_index(:agents_branches, :postcode)
    add_index(:agents_branches, :district)
  end
end
