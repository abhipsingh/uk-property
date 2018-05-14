class AgentFloorplanRequestNotifyWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(agent_id, buyer_id, property_id)
    agent_attrs = Agents::Branches::AssignedAgent.where(id: agent_id).select([:first_name, :last_name, :email]).last.as_json
    property_attrs = PropertyDetails.details(property_id)[:_source]
    buyer_attrs = PropertyBuyer.where(id: buyer_id).select([:first_name, :last_name, :email, :mobile]).last.as_json
    AgentMailer.send_floorplan_request_mailer(agent_attrs, buyer_attrs, property_attrs).deliver_now
  end
end

