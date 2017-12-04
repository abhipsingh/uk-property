class AddEmailToDevelopers < ActiveRecord::Migration
  def change
    add_column(:developers_groups, :email, :string)
    add_column(:developers_companies, :email, :string)
    add_column(:developers_branches, :email, :string)
    add_column(:developers_branches_employees, :email, :string)
  end
end
