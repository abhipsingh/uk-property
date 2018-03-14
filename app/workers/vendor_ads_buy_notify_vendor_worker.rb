class VendorAdsBuyNotifyVendorWorker
  include Sidekiq::Worker

  def perform(property_id)
    details = PropertyDetails.details(property_id)[:_source]
    vendor_email = details[:vendor_email]
    vendor_property_address = details[:address]
    template_data = { vendor_property_address: vendor_property_address }
    destination = nil
    ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' : destination = vendor_email
    destination_addrs = []
    destination_addrs.push(destination)
    client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
    resp = client.send_templated_email({ source: 'alerts@prophety.co.uk', destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_ads_buy_notify_vendor', template_data: template_data.to_json})
  end

end

