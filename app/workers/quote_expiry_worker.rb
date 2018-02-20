### TODO: Daily night worker
class QuoteExpiryWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform
    klass = Agents::Branches::AssignedAgents::Quote
    new_status = klass::STATUS_HASH['New']
    entity_class = AgentCreditVerifier::KLASSES.index(klass.to_s)

    ### Give the vendor 24 hours to respond. First refund all the agents their credits back
    ### and then expire them
    expired_before_time = Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME.ago
    agent_quotes = klass.where.not(agent_id: nil).where(status: new_status).where(expired: false).where('created_at < ?', expired_before_time)
    agent_quotes.each do |each_agent_quote|
      current_valuation = each_agent_quote.amount
      credits = ((Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(current_valuation.to_f)).to_i/Agents::Branches::AssignedAgent::PER_CREDIT_COST)
      agent = each_agent_quote.agent
      agent_credit_verifier = AgentCreditVerifier.where(entity_class: entity_class, entity_id: each_agent_quote.id).last

      ### Verifying the credit info
      if agent_credit_verifier && agent_credit_verifier.amount == current_valuation.to_i && agent_credit_verifier.is_refund == false
        agent_credit_verifier.is_refund = true
        agent.credit += credits
        each_agent_quote.expired = true

        ### Save all credit verifier and agent info and agent quote
        agent_credit_verifier.save!
        agent.save!
        each_agent_quote.save!
      end
    end

    vendor_quotes = klass.where(agent_id: nil).where(status: new_status).where(expired: false).where('created_at < ?', expired_before_time).update_all(expired: true)

  end

end

