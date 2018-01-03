class AddUniqueIndexToAgentCreditVerfier < ActiveRecord::Migration
  def change
    add_index(:agent_credit_verifiers, [:udprn, :vendor_id, :agent_id, :is_refund, :entity_class], unique: true, name: 'agent_credit_unique_idx')
  end
end

