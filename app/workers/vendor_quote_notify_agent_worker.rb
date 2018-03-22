class VendorQuoteAgentNotifyWorker
  include Sidekiq::Worker
  include SesEmailSender
  sidekiq_options :retry => false # job will be discarded immediately if failed

  ### Sent to agents when a quote is created by the vendor
  def perform(quote_id)
    quote = Agents::Branches::AssignedAgents::Quote.where(id: quote_id.to_i).last
    details = PropertyDetails.details(quote.property_id)[:_source]
    district = details[:district]

    agents = Agents::Branches::AssignedAgent.joins(:branch)
                                            .where("(agents_branches.district = ? AND agents_branches_assigned_agents.locked = 'f') OR (agents_branches_assigned_agents.id = ?)", district, quote.existing_agent_id)
                                            .where("agents_branches_assigned_agents.is_first_agent = 'f'")
                                            .select([:first_name, :email])

    agents.each do |agent|
      template_data = { agent_first_name: agent.first_name }
      self.class.send_email(agent.email, 'agent_quote_notify', self.class.to_s, template_data)
    end

  end

end

