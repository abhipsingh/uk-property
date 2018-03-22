class VendorAcceptQuoteNotifyAgentWorker
  include SesEmailSender
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
        self.class.send_email(agent.email, 'vendor_quote_lost_notify_agent', self.class.to_s, template_data)
      end

      winning_agent_details = Agents::Branches::AssignedAgent.where(id: winning_quote.agent_id).last
      if winning_agent_details
        agent = winning_agent_details
        address = PropertyDetails.details(property_id)[:_source][:address]
        template_data = { agent_first_name: agent.first_name, vendor_property_address: address }
        self.class.send_email(agent.email, 'vendor_accept_quote_notify_agent', self.class.to_s, template_data)
      end

    end

  end

end

