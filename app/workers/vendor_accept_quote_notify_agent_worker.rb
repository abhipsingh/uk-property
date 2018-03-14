class VendorAcceptQuoteNotifyAgentWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  ### Sent to vendors when a quote is made by the agent
  def perform(property_id, agent_id)
    won_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
    lost_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Lost']
    winning_quote = Agents::Branches::AssignedAgents::Quote.where(property_id: property_id, parent_quote_id: nil, agent_id: agent_id, status: won_status)
                                                           .order('created_at DESC').limit(1).first

    if winning_quote
      losing_agents = Agents::Branches::AssignedAgents::Quote.where(parent_quote_id: winning_quote.id, status: lost_status).pluck(:agent_id)
      losing_agent_details = Agents::Branches::AssignedAgent.where(id: losing_agents).select([:first_name, :email])

      losing_agent_details.each do |agent|
        template_data = { agent_first_name: agent.first_name }
        destination = nil
        ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = agent.email
        destination_addrs = []
        destination_addrs.push(destination)
        client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
        resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_quote_lost_notify_agent', template_data: template_data.to_json})
      end

      winning_agent_details = Agents::Branches::AssignedAgent.where(id: winning_quote.agent_id).last
      if winning_agent_details
        agent = winning_agent_details
        address = PropertyDetails.details(property_id)[:_source][:address]
        template_data = { agent_first_name: agent.first_name, vendor_property_address: address }
        destination = nil
        ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = agent.email
        destination_addrs = []
        destination_addrs.push(destination)
        client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
        resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'vendor_accept_quote_notify_agent', template_data: template_data.to_json})
      end

    end

  end

end

