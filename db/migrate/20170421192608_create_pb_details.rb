class CreatePbDetails < ActiveRecord::Migration
  def change
    create_table :pb_details do |t|
      t.jsonb :details

      t.timestamps null: false
    end
  end
end
