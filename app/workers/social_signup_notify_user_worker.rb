class SocialSignupNotifyUserWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(user_email, provider)
    template_data = { vendor_email_address: user_email }
    destination = nil
    ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' : destination = user_email
    destination_addrs = []
    destination_addrs.push(destination)
    client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
    provider == 'facebook' ? template_name = 'vendor_fb_registration' : template_name = 'vendor_linkedin_registration'
    resp = client.send_templated_email({ source: 'alerts@prophety.co.uk', destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_registration_manual', template_data: template_data.to_json})
  end

end

