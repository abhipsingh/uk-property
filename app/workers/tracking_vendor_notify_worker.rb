class TrackingVendorNotifyWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(vendor_id, agent_id, udprn, type_of_tracking)
    vendor = Vendor.where(id: vendor_id).select(:email).select(:first_name).select(:id).last
    agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: agent_id).first
    if type_of_tracking.to_sym == :property_tracking
      details = PropertyDetails.details(udprn)[:_source]
      address = details[:address]

      if vendor 
        destination_addrs = []
        template_data = { vendor_first_name: vendor.first_name, vendor_property_address: address }
        ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = vendor.email
        destination_addrs.push(destination)
        client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
        resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: "vendor_tracking_notify", template_data: template_data.to_json})
      end

      if agent
        destination_addrs = []
        template_data = { agent_first_name: agent.first_name, vendor_property_address: address }
        ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = agent.email
        destination_addrs.push(destination)
        client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
        resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: "agent_tracking_notify", template_data: template_data.to_json})
      end

    end
  end

end

