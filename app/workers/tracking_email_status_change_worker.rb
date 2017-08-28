class TrackingEmailStatusChangeWorker
  include Sidekiq::Worker

  def perform(params_hash)
    udprn = params_hash['udprn']
    buyers = PropertyBuyer.filter_buyers(udprn)
    last_property_status_type = params_hash['last_property_status_type']
    current_property_status_type = params_hash['property_status_type']
    buyers.each do |each_buyer|
      BuyerMailer.tracking_emails(buyer, params_hash).deliver_now
    end
  end
end

