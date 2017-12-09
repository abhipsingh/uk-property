class CreateInvitedVendors < ActiveRecord::Migration
  def change
    create_table :invited_vendors do |t|
      t.string :email
      t.integer :agent_id
      t.integer :udprn
      t.integer :source
      t.timestamp :created_at, null: false
    end
  end
end

