class CreateInvitedFandFVendors < ActiveRecord::Migration
  def change
    create_table :invited_fand_f_vendors do |t|
      t.string :email
      t.integer :invitee_id
      t.timestamp :created_at, null: false
    end
  end
end
