class CreateDevelopersBranches < ActiveRecord::Migration
  def change
    create_table :developers_branches do |t|
      t.string :name
      t.string :image_url
      t.string :website
      t.string :phone_number
      t.string :address
      t.string :district
      t.string :domain_name
      t.integer :company_id
      t.timestamp :created_at, null: false
    end
  end
end

