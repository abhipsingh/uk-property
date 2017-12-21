class TrackingEmailStatusChangeWorker
  include Sidekiq::Worker

  def perform(params_hash)
    udprn = params_hash['udprn']
    buyers = PropertyBuyer.filter_buyers(udprn)
    buyers.each do |each_buyer|
      #BuyerMailer.tracking_emails(each_buyer, params_hash).deliver_now
    end
  end
end
