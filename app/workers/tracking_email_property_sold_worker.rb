class TrackingEmailPropertySoldWorker
  include Sidekiq::Worker

  def perform(params_hash)
    udprn = params_hash['udprn']
    buyers = PropertyBuyer.filter_buyers(udprn)
    buyers.each do |each_buyer|
    end
  end
end

