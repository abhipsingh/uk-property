class CreateDevelopersCompanies < ActiveRecord::Migration
  def change
    create_table :developers_companies do |t|
      t.string :name
      t.string :image_url
      t.string :website
      t.string :phone_number
      t.string :address
      t.integer :group_id, index: true
      t.timestamp :created_at, null: false
    end
  end
end
