class AgentUpgradePremiumNotifyAgentWorker
  include Sidekiq::Worker

  def perform(agent_id)
    agent = Agents::Branches::AssignedAgent.where(id: agent_id).unscope(where: :is_developer).last
    if agent
      agent_first_name = agent.first_name
      agent_email = agent.email
      template_data = { agent_first_name: agent_first_name }
      destination = nil
      ENV['EMAIL_ENV'] == 'dev' ? destination = 'test@prophety.co.uk' : destination = agent_email
      destination_addrs = []
      destination_addrs.push(destination)
      client = Aws::SES::Client.new(access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret, region: 'us-east-1')
      resp = client.send_templated_email({ source: 'alerts@prophety.co.uk', destination: { to_addresses: destination_addrs, cc_addresses: [], bcc_addresses: [], }, tags: [], template: 'agent_upgrade_premium_notify_agent', template_data: template_data.to_json})
    end
  end

end

