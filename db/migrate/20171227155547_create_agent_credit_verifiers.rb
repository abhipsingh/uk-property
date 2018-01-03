class CreateAgentCreditVerifiers < ActiveRecord::Migration
  def change
    create_table :agent_credit_verifiers do |t|
      t.integer :entity_id
      t.integer :agent_id
      t.integer :udprn
      t.integer :vendor_id
      t.integer :entity_class
      t.integer :amount
      t.boolean :is_refund, default: false
      t.timestamps null: false
    end
  end
end

