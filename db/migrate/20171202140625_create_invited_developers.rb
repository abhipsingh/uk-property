class CreateInvitedDevelopers < ActiveRecord::Migration
  def change
    create_table :invited_developers do |t|
      t.string :email
      t.integer :udprn
      t.integer :developer_id
      t.timestamps null: false
    end
  end
end
