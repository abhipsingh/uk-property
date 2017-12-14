class QuoteRefundWorker
  include Sidekiq::Worker
  sidekiq_options :retry => true

  ### Instantaneous worker
  def perform(udprn)
    klass = Agents::Branches::AssignedAgents::Quote
    lost_status = klass::STATUS_HASH['Lost']
    Agents::Branches::AssignedAgents::Quote.where(property_id: udprn.to_i).where.not(agent_id: nil).where("status = ? OR expired = 't'", lost_status).each do |quote|
      ### Get the stripe charge & refund each of the charges
      charge_id = Stripe::Payment.where(udprn: udprn.to_i).where(entity_type: Stripe::Payment::USER_TYPES['Agent'], entity_id: quote.agent_id)
                                 .order('created_at desc').last.charge_id
      if charge_id
        refund = Stripe::Refund.create(charge: charge_id)
        quote.refund_status = true && quote.save! if refund.status == 'succeeded'
      end
    end
  end

end

