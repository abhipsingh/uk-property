class VendorManualRegistrationWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(vendor_email, link)
    template_data = { vendor_email_address: vendor_email, vendor_manual_registration_first_time_login_url: link }
    destination = nil
    ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' : destination = vendor_email
    destination_addrs = []
    destination_addrs.push(destination)
    client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
    resp = client.send_templated_email({ source: 'alerts@prophety.co.uk', destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_registration_manual', template_data: template_data.to_json})
  end

end

