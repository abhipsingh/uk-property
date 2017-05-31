class AgentService
  attr_accessor :agent_id, :udprn

  def initialize(agent_id, udprn)
    @agent_id = agent_id
    @udprn = udprn
  end

  ### When an agent verifies a crawled property
  ### Called from agents_controller#verify_property_from_agent
  def verify_crawled_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    assigned_agent = Agents::Branches::AssignedAgent.where(email: assigned_agent_email).first
    if assigned_agent
      property_attrs[:agent_id] = assigned_agent.id
    else
      InvitedAgent.create!(email: assigned_agent_email, udprn: udprn)
      branch.invited_agents = [{ branch_id: branch.id, company_id: branch.agent_id, email: assigned_agent_email }]
      branch.save!
      branch.send_emails
    end
    property_id = property_attrs[:property_id]
    Agents::Branches::CrawledProperty.where(id: property_id).update_all({udprn: udprn})
    response, status = PropertyDetails.update_details(client, udprn, property_attrs)
    vendor_email = params[:vendor_email]
    Agents::Branches::AssignedAgent.find(@agent_id).send_vendor_email(vendor_email, @udprn)
    return response, status
  end

  def verify_manual_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    assigned_agent = Agents::Branches::AssignedAgent.where(email: assigned_agent_email).first
    if assigned_agent
      property_attrs[:agent_id] = assigned_agent.id
    else
      InvitedAgent.create!(email: assigned_agent_email, udprn: udprn)
      branch.invited_agents = [{ branch_id: branch.id, company_id: branch.agent_id, email: assigned_agent_email }]
      branch.save!
      branch.send_emails
    end
    property_id = property_attrs[:property_id]
    response, status = PropertyDetails.update_details(client, udprn, property_attrs)
    vendor_email = params[:vendor_email]
    Agents::Branches::AssignedAgent.find(@agent_id).send_vendor_email(vendor_email, @udprn)
    return response, status
  end
end
