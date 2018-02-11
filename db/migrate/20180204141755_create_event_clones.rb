class CreateEventClones < ActiveRecord::Migration
  def change
    create_table :event_clones do |t|
      t.integer :agent_id
      t.integer :udprn
      t.integer :type_of_match, limit: 2
      t.integer :event, limit: 2
      t.integer :buyer_id
      t.boolean :is_archived
      t.integer :rating, limit: 2
      t.datetime :scheduled_visit_time
      t.integer :offer_price
      t.date :offer_date
      t.date :expected_completion_date
      t.timestamp :created_at, null: false
    end
  end
end
