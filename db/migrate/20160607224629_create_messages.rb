class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.text :content
      t.integer :from
      t.integer :to

      t.timestamps null: false
    end

    add_index(:messages, :from)
    add_index(:messages, :to)
  end
end
