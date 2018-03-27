class AgentQuoteNotifyVendorWorker
  include Sidekiq::Worker
  include SesEmailSender
  sidekiq_options :retry => false # job will be discarded immediately if failed

  ### Sent to vendors when a quote is made by the agent
  def perform(quote_id)
    quote = Agents::Branches::AssignedAgents::Quote.where(id: quote_id.to_i).last
    property_id = quote.property_id
    details = PropertyDetails.details(property_id)[:_source]
    agent_id = quote.agent_id
    vendor_first_name = details[:vendor_first_name]
    vendor_email = details[:vendor_email]
    address = details[:address]

    assigned_agent = Agents::Branches::AssignedAgent.where(id: agent_id).last
    agent_first_name = assigned_agent.first_name
    agent_last_name = assigned_agent.last_name
    agent_branch_name = assigned_agent.branch.name

    if quote
      template_data = { vendor_first_name: vendor_first_name, vendor_property_address: address, agent_first_name: agent_first_name,
                        agent_last_name: agent_last_name, agent_branch_name: agent_branch_name }
      self.class.send_email(vendor_email, 'vendor_quote_notify', self.class.to_s, template_data)
    end

  end

end

