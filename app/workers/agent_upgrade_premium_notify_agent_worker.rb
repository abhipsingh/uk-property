class AgentUpgradePremiumNotifyAgentWorker
  include SesEmailSender
  include Sidekiq::Worker

  def perform(agent_id)
    agent = Agents::Branches::AssignedAgent.where(id: agent_id).unscope(where: :is_developer).last
    if agent
      agent_first_name = agent.first_name
      agent_email = agent.email
      template_data = { agent_first_name: agent_first_name }
      self.class.send_email(agent.email, 'agent_upgrade_premium_notify_agent', self.class.to_s, template_data)
    end
  end

end

