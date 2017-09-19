class AdsExpiryWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed
  def perform
    begin
      PropertyAd.where("expiry_at > ?", Time.now).destroy_all
    rescue Exception => e
      Rails.logger.info("ERROR_AdsExpiryWorker_#{e}")
      tomorrow_midnight = Time.parse(Date.tomorrow.to_s + " 00:00:00 UTC")
      AdsExpiryWorker.perform_at(tomorrow_midnight)
    end
  end
end
