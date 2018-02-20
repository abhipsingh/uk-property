class QuoteRefundWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  ### Instantaneous worker
  def perform(udprn, parent_quote_id)
    klass = Agents::Branches::AssignedAgents::Quote
    lost_status = klass::STATUS_HASH['Lost']
    entity_class = AgentCreditVerifier::KLASSES.index(klass.to_s)
    Agents::Branches::AssignedAgents::Quote.where(property_id: udprn.to_i, parent_quote_id: parent_quote_id).where.not(agent_id: nil).where("status = ?", lost_status).each do |quote|
##     Get the stripe charge & refund each of the charges
#      charge_id = Stripe::Payment.where(udprn: udprn.to_i).where(entity_type: Stripe::Payment::USER_TYPES['Agent'], entity_id: quote.agent_id)
#                                 .order('created_at desc').last.charge_id
#      if charge_id
#        refund = Stripe::Refund.create(charge: charge_id)
#        quote.refund_status = true && quote.save! if refund.status == 'succeeded'
#      end
      agent = quote.agent
      udprn = quote.property_id
      current_valuation = quote.amount
      refund_credits = ((Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(current_valuation.to_f)).to_i/Agents::Branches::AssignedAgent::PER_CREDIT_COST)          
      agent_credit_verifier = AgentCreditVerifier.where(entity_class: entity_class, entity_id: quote.id).last
      agent = quote.agent

      if agent_credit_verifier && agent_credit_verifier.amount == current_valuation.to_i && agent_credit_verifier.is_refund == false
        agent_credit_verifier.is_refund = true
        agent.credit += refund_credits

        ### Save both credit verifier and agent info
        agent_credit_verifier.save!
        agent.save!
      end
    end
  end

end

