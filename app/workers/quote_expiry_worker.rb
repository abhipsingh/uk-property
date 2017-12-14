### TODO: Daily night worker
class QuoteExpiryWorker
  include Sidekiq::Worker
  sidekiq_options :retry => true

  def perform(udprn)
    klass = Agents::Branches::AssignedAgents::Quote
    new_status = klass::STATUS_HASH['New']

    ### Give the vendor 24 hours to respond
    klass.where.not(agent_id: nil).where(status: new_status).where('created_at < ?', klass::MAX_AGENT_QUOTE_WAIT_TIME).update_all(expired: true)

    ### Give the agents 48 hours to respond
    klass.where(agent_id: nil).where(status: new_status).where('created_at < ?', klass::MAX_VENDOR_QUOTE_WAIT_TIME).update_all(expired: true)
  end

end

