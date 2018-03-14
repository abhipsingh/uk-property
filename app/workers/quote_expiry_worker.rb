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
    expired_vendor_quotes = klass.where(parent_quote_id: nil, expired: false).where(status: new_status).where('created_at < ?', expired_before_time)
    expired_vendor_quotes.map { |t| Rails.logger.info("EXPIRED_VENDOR_QUOTE_#{t.id}") }

    expired_vendor_quotes.each do |expired_vendor_quote|

      agent_quotes = klass.where(parent_quote_id: expired_vendor_quote.id, expired: false)
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
          
          template_data = { agent_first_name: agent.first_name }
          destination = nil
          ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = agent.email
          destination_addrs = []
          destination_addrs.push(destination)
          client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
          resp = client.send_templated_email({ source: 'alerts@prophety.co.uk', destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_quote_expired_notify_agent', template_data: template_data.to_json})
          Rails.logger.info("EXPIRED_AGENT_QUOTE_#{each_agent_quote.agent_id}")

          ### Save all credit verifier and agent info and agent quote
          agent_credit_verifier.save!
          agent.save!
          each_agent_quote.save!
        end
      end

      expired_vendor_quote.expired = true
      expired_vendor_quote.save!

    end

  end

end

