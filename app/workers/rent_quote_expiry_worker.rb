### TODO: Daily night worker
class RentQuoteExpiryWorker
  include SesEmailSender
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform
    klasses = [Rent::Quote ]
    klasses.each do |klass|
      new_status = klass::STATUS_HASH['New']
      entity_class = AgentCreditVerifier::KLASSES.index(klass.to_s)
      Rails.logger.info("RentQuoteExpiryWorker_STARTED")
  
      ### Give the vendor 24 hours to respond. First refund all the agents their credits back
      ### and then expire them
      expired_before_time = klass::MAX_VENDOR_QUOTE_WAIT_TIME.ago
      expired_vendor_quotes = klass.where(parent_quote_id: nil, expired: false).where(status: new_status).where('created_at < ?', expired_before_time)
      expired_vendor_quotes.each { |t| Rails.logger.info("QuoteExpiryWorker_EXPIRED_VENDOR_QUOTE_STARTED_#{t.id}") }
  
      expired_vendor_quotes.each do |expired_vendor_quote|
        Rails.logger.info("RentQuoteExpiryWorker_EXPIRED_VENDOR_QUOTE_PROCESSING_START_#{expired_vendor_quote.id}")

        agent_quotes = klass.where(parent_quote_id: expired_vendor_quote.id, expired: false)
        agent_quotes.each do |each_agent_quote|
          Rails.logger.info("RentQuoteExpiryWorker_AGENT_QUOTE_EXPIRY_PROCESSING_START_#{each_agent_quote.id}")
  
          each_agent_quote.expired = true
          #template_data = { agent_first_name: agent.first_name }
          #self.class.send_email(agent.email, 'vendor_quote_expired_notify_agent', self.class.to_s, template_data)

          ### Save all credit verifier and agent info and agent quote
          each_agent_quote.save!
          Rails.logger.info("RentQuoteExpiryWorker_AGENT_QUOTE_EXPIRY_REFUND_PROCESSING_END_#{each_agent_quote.id}")
        end
  
        expired_vendor_quote.expired = true
        expired_vendor_quote.save!
        Rails.logger.info("RentQuoteExpiryWorker_EXPIRED_VENDOR_QUOTE_PROCESSING_END_#{expired_vendor_quote.id}")
  
      end
      Rails.logger.info("RentQuoteExpiryWorker_FINISHED")
    end

  end

end

