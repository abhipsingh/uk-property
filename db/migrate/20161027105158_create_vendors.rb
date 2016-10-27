class CreateVendors < ActiveRecord::Migration
  def change
    create_table :vendors do |t|
      t.string :full_name
      t.integer :property_id
      t.string :email
      t.string :mobile
      t.integer :status

      t.timestamps null: false
    end
  end
end
