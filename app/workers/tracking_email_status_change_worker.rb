class TrackingEmailStatusChangeWorker
  include Sidekiq::Worker

  def perform(params_hash)
    udprn = params_hash['udprn']
    buyers = PropertyBuyer.filter_buyers(udprn)
  end
end

