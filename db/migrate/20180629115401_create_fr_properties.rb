class CreateFrProperties < ActiveRecord::Migration
  def change
    create_table :fr_properties do |t|
      t.string :udprn
      t.integer :pt
      t.integer :county
      t.string :dl
      t.string :dtd

      t.timestamps null: false
    end
  end
end
