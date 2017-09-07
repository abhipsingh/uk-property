class AssignedAgentChangeWorker
  include Sidekiq::Worker

  def perform(details, previous_agent_id)
    prev_agent = Agents::Branches::AssignedAgent.find(previous_agent_id)
    new_agent = Agents::Branches::AssignedAgent.find(details['agent_id'])
    vendor = Vendor.find(details['vendor_id'])
    AgentMailer.send_email_on_assigned_agent_change_to_previous_agent(prev_agent, details, vendor, details['reason'], details['time'])
    AgentMailer.send_email_on_assigned_agent_change_to_admin(prev_agent, new_agent, details, vendor, details['reason'], details['time'])
  end
end