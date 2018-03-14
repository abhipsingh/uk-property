class AgentVendorEnquiryNotifyWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(property_id)
    details = PropertyDetails.details(property_id)[:_source]
    agent_first_name = details[:assigned_agent_first_name]
    agent_email = details[:assigned_agent_email]
    vendor_first_name = details[:vendor_first_name]
    vendor_email = details[:vendor_email]
    address = details[:address]

    if vendor_first_name && vendor_email
      destination_addrs = []
      template_data = { vendor_first_name: vendor_first_name, vendor_property_address: address }
      ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = vendor_email
      destination_addrs.push(destination)
      client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
      resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: "vendor_enquiry_notify", template_data: template_data.to_json})
    end

    if agent_first_name && agent_email
      destination_addrs = []
      template_data = { agent_first_name: agent_first_name, vendor_property_address: address }
      ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = agent_email
      destination_addrs.push(destination)
      client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
      resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: "agent_enquiry_notify", template_data: template_data.to_json})
    end

  end

end

