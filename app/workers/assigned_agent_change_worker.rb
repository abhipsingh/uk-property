class AssignedAgentChangeWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(details, previous_agent_id)
    prev_agent = Agents::Branches::AssignedAgent.find(previous_agent_id)
    new_agent = Agents::Branches::AssignedAgent.find(details['agent_id'])
    vendor = Vendor.where(id: details['vendor_id'].to_i).last
    if vendor
      AgentMailer.send_email_on_assigned_agent_change_to_previous_agent(prev_agent, details, vendor, details['reason'], details['time']).deliver_now
      AgentMailer.send_email_on_assigned_agent_change_to_admin(prev_agent, new_agent, details, vendor, details['reason'], details['time']).deliver_now
    end

    ### Flush agent's cached tables
    ardb_client = Rails.configuration.ardb_client
    ardb_client.del("cache_#{previous_agent_id}_agent_new_enquiries")

  end
end
