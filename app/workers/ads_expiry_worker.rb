class AdsExpiryWorker
  include SesEmailSender
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed
  def perform
    ### Destroy all ads where expiry is less than the current time
    Rails.logger.info("AdsExpiryWorker_STARTED")
    expired_ads = PropertyAd.where("expiry_at < ?", Time.now)
    expired_ads.each {|t| Rails.logger.info("AdsExpiryWorker_PROCESSING_#{ad.id}") }
    expired_ads.destroy_all

    ### Send email to ads which are going to expire the next day
    ads_about_to_expire = PropertyAd.where("expiry_at < ?", Time.now - 1.day)

    ads_about_to_expire.each do |ad|
      Rails.logger.info("AdsExpiryWorker_ABOUT_TO_EXPIRE_PROCESSING_STARTED_#{ad.id}")
      udprn = ad.udprn
      details = PropertyDetails.details(ad.udprn)[:_source]
      vendor_email = details[:vendor_email]
      vendor_property_address = details[:address]
      if vendor_email
        template_data = { vendor_property_address: vendor_property_address }
        self.class.send_email(vendor_email, 'vendor_quote_lost_notify_agent', self.class.to_s, template_data)
      end
      Rails.logger.info("AdsExpiryWorker_ABOUT_TO_EXPIRE_PROCESSING_FINISHED_#{ad.id}")
    end

    Rails.logger.info("AdsExpiryWorker_FINISHED")

  end
end
