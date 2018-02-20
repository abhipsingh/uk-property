class AdsExpiryWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed
  def perform
    begin
      PropertyAd.where("expiry_at > ?", Time.now).destroy_all
    rescue Exception => e
      Rails.logger.info("ERROR_AdsExpiryWorker_#{e}")
    end
  end
end
