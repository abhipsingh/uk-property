class AgentQuoteNotifyVendorWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  ### Sent to vendors when a quote is made by the agent
  def perform(quote_id)
    quote = Agents::Branches::AssignedAgents::Quote.where(id: quote_id.to_i).last
    property_id = quote.property_id
    details = PropertyDetails.details(property_id)[:_source]
    vendor_first_name = details[:vendor_first_name]
    vendor_email = details[:vendor_email]
    address = details[:address]

    if quote
      template_data = { vendor_first_name: vendor_first_name, vendor_property_address: address }
      destination = nil
      ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = vendor_email
      destination_addrs = []
      destination_addrs.push(destination)
      client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
      resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_quote_notify', template_data: template_data.to_json})
    end

  end

end

