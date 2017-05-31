class CreateInvitedAgents < ActiveRecord::Migration
  def change
    create_table :invited_agents do |t|
      t.string :email
      t.integer :udprn

      t.timestamps null: false
    end
  end
end
