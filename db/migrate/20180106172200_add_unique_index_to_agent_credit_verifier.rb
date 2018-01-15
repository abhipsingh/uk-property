class AddUniqueIndexToAgentCreditVerifier < ActiveRecord::Migration
  def change
    remove_index(:agent_credit_verifiers, name: 'agent_credit_unique_idx')
    add_index(:agent_credit_verifiers, [:agent_id, :entity_id, :is_refund], name: 'agent_credit_unique_refund_idx', unique: true)
  end
end
