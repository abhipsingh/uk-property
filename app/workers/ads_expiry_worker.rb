class AdsExpiryWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed
  def perform
    ### Destroy all ads where expiry is less than the current time
    PropertyAd.where("expiry_at < ?", Time.now).destroy_all

    ### Send email to ads which are going to expire the next day
    ads_about_to_expire = PropertyAd.where("expiry_at < ?", Time.now - 1.day)

    ads_about_to_expire.each do |ad|
      udprn = ad.udprn
      details = PropertyDetails.details(ad.udprn)[:_source]
      vendor_email = details[:vendor_email]
      vendor_property_address = details[:address]
      if vendor_email
        template_data = { vendor_property_address: vendor_property_address }
        destination = nil
        ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = vendor_email
        destination_addrs = []
        destination_addrs.push(destination)
        client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
        resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_quote_lost_notify_agent', template_data: template_data.to_json})
      end
    end

  end
end
