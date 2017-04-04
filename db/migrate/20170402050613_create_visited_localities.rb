class CreateVisitedLocalities < ActiveRecord::Migration
  def change
    create_table :visited_localities do |t|
      t.string :locality

      t.timestamps null: false
    end
    add_index(:visited_localities, :locality)
  end
end
