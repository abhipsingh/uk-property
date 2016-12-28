class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.integer :agent_id
      t.integer :udprn
      t.jsonb :message
      t.integer :type_of_match, limit: 2
      t.integer :event, limit: 2
      t.integer :buyer_id
      t.string :buyer_name
      t.string :buyer_email
      t.string :buyer_mobile
      t.string :agent_name
      t.string :agent_email
      t.string :agent_mobile
      t.string :address

      t.timestamp :created_at, null: false
    end
  end
end
