class VendorUpgradePremiumNotifyVendorWorker
  include Sidekiq::Worker

  def perform(vendor_id)
    vendor = Vendor.find(vendor_id)
    vendor_first_name = vendor.first_name
    vendor_email = vendor.email
    template_data = { vendor_first_name: vendor_first_name }
    destination = nil
    ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' : destination = vendor_email
    destination_addrs = []
    destination_addrs.push(destination)
    client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
    resp = client.send_templated_email({ source: 'alerts@prophety.co.uk', destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_upgrade_premium_notify_vendor', template_data: template_data.to_json})
  end

end

