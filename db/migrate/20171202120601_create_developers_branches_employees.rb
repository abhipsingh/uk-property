class CreateDevelopersBranchesEmployees < ActiveRecord::Migration
  def change
    create_table :developers_branches_employees do |t|
      t.string :name
      t.string :image_url
      t.string :phone_number
      t.integer :branch_id

      t.timestamp :created_at, null: false
    end
  end
end

