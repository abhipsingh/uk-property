class TrackingEmailPropertySoldWorker
  include Sidekiq::Worker

  def perform(params_hash)
    udprn = params_hash['udprn']
    buyers = PropertyBuyer.filter_buyers(udprn)
    buyers.each do |each_buyer|
      BuyerMailer.offer_made_stage_emails(buyer, params_hash).deliver_now
    end
  end
end

