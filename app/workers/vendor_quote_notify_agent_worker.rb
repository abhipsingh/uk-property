class VendorQuoteAgentNotifyWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  ### Sent to vendors when a quote is made by the agent
  def perform(quote_id)
    quote = Agents::Branches::AssignedAgents::Quote.where(id: quote_id.to_i).last
    details = PropertyDetails.details(quote.property_id)[:_source]
    district = details[:district]

    agents = Agents::Branches::AssignedAgent.joins(:branch)
                                            .where('agents_branches.district = ?', district)
                                            .where("agents_branches.locked = 'f'")
                                            .select([:first_name, :email])

    agents.each do |agent|
      template_data = { agent_first_name: agent.first_name }
      destination = nil
      ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' :  destination = agent.email
      destination_addrs = []
      destination_addrs.push(destination)
      client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
      resp = client.send_templated_email({ source: "alerts@prophety.co.uk", destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'agent_quote_notify', template_data: template_data.to_json})
    end

  end

end

