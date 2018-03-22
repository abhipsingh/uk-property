class AgentVendorLeadNotifyWorker
  include SesEmailSender
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(property_id)
    details = PropertyDetails.details(property_id)[:_source]
    agent_first_name = details[:assigned_agent_first_name]
    agent_last_name = details[:assigned_agent_last_name]
    agent_email = details[:assigned_agent_email]
    vendor_first_name = details[:vendor_first_name]
    vendor_email = details[:vendor_email]
    address = details[:address]
    agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: details[:agent_id]).last

    if vendor_first_name && vendor_email && agent
      agent_job_title = agent.title
      branch = agent.branch
      destination_addrs = []
      template_data = { vendor_first_name: vendor_first_name, agent_first_name: agent_first_name, agent_last_name: agent_last_name, agent_job_title: agent_job_title,
                        agent_branch_name: details[:assigned_agent_branch_name], agent_mobile_number: agent.mobile, agent_email_address: agent.email,
                        agent_branch_address: branch.address, agent_branch_website: branch.website }
      self.class.send_email(vendor_email, 'vendor_lead_notify', self.class.to_s, template_data)
    end

    if agent_first_name && agent_email
      destination_addrs = []
      template_data = { agent_first_name: agent_first_name }
      self.class.send_email(agent_email, 'agent_lead_notify', self.class.to_s, template_data)
    end

  end

end

