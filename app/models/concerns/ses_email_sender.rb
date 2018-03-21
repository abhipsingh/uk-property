module SesEmailSender
  extend ActiveSupport::Concern

  included do
  end

  module ClassMethods

    def send_email(email_address, template_name, klass, template_data)
      destination = nil
      ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' : destination = email_address
      destination_addrs = []
      destination_addrs.push(destination)
      client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
      resp = client.send_templated_email({ source: 'alerts@prophety.co.uk', destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: template_name, template_data: template_data.to_json})
      SesEmailRequest.create!(email: email_address, template_name: template_name, template_data: template_data, klass: klass)
    end

  end
end

