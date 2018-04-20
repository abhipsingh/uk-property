class AgentService
  attr_accessor :agent_id, :udprn

  def initialize(agent_id, udprn)
    @agent_id = agent_id
    @udprn = udprn
  end

  def verify_manual_property_from_agent_non_f_and_f(property_attrs, vendor_email, assigned_agent_email, agent)
    assigned_agent = agent
    branch = Agents::Branches::AssignedAgent.where(id: @agent_id.to_i).last.branch
    property_id = property_attrs[:property_id]
    details = PropertyDetails.details(@udprn)[:_source]
    Rails.logger.info("#{@udprn}__#{details[:address]}")
    address = details[:address]
    assigned_agent_present = !(Agents::Branches::AssignedAgent.where(email: assigned_agent_email).last.nil?)
    response, status = PropertyService.new(udprn).update_details(property_attrs)
    agent_attrs = {
      name: assigned_agent.first_name.to_s + ' ' + assigned_agent.last_name.to_s,
      branch_address: branch.address,
      title: assigned_agent.title,
      company_name: branch.agent.name,
      office: assigned_agent.office_phone_number,
      mobile: assigned_agent.mobile_phone_number,
      email: assigned_agent.email,
      address: address,
      udprn: udprn,
      hash_link: assigned_agent.create_hash(vendor_email, property_id).hash_value
    }

    Agents::Branches::AssignedAgent.find(@agent_id).send_vendor_email(vendor_email, @udprn, assigned_agent_present, assigned_agent_email)

    ### Add this vendor to invited vendors table, source
    InvitedVendor.create!(udprn: @udprn, email: vendor_email, agent_id: @agent_id.to_i, source: Vendor::INVITED_FROM_CONST[:non_crawled] )

    return response, status
  end

  ### When an agent verifies a crawled property
  ### Called from agents_controller#verify_property_from_agent
  def verify_crawled_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    assigned_agent = Agents::Branches::AssignedAgent.where(email: assigned_agent_email).first
    branch = Agents::Branches::AssignedAgent.where(id: @agent_id.to_i).last.branch
    if assigned_agent
      property_attrs[:agent_id] = assigned_agent.id
      property_attrs[:agent_status] = 2
      assigned_agent_present = true
    else
      #InvitedAgent.create!(email: assigned_agent_email, udprn: udprn, entity_id: @agent_id.to_i, branch_id: assigned_agent.branch_id)
      branch_invited_agents = branch.invited_agents
      branch.invited_agents = [{ branch_id: branch.id, company_id: branch.agent_id, email: assigned_agent_email, entity_id: @agent_id.to_i, udprn: udprn }]
      branch.send_emails
      branch_invited_agents ||= []
      branch.invited_agents += branch_invited_agents
      branch.save!
      assigned_agent_present = false
    end
    property_id = property_attrs[:property_id]
    response, status = verify_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    Agents::Branches::CrawledProperty.where(id: property_id).update_all({udprn: udprn})
    return response, status
  end

  def verify_manual_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    assigned_agent = Agents::Branches::AssignedAgent.where(email: assigned_agent_email).first
    branch = Agents::Branches::AssignedAgent.where(id: @agent_id.to_i).last.branch
    property_id = property_attrs[:property_id]
    details = PropertyDetails.details(property_id)['_source']
    address = details['address']
    vendor = Vendor.where(email: vendor_email).last
    property_attrs[:vendor_id] = vendor.id if vendor
    response, status = PropertyService.new(udprn).update_details(property_attrs)
    property_service = PropertyService.new(property_id)
    property_service.claim_new_property_manual(assigned_agent.id)
    agent_attrs = {
      name: assigned_agent.first_name.to_s + ' ' + assigned_agent.last_name.to_s,
      branch_address: branch.address,
      title: assigned_agent.title,
      company_name: branch.agent.name,
      office: assigned_agent.office_phone_number,
      mobile: assigned_agent.mobile_phone_number,
      email: assigned_agent.email,
      address: address,
      udprn: udprn,
      hash_link: assigned_agent.create_hash(vendor_email, property_id).hash_value
    }

    VendorMailer.agent_lead_expect_visit_manual(agent_attrs, vendor_email).deliver_now

    ### Add this vendor to invited vendors table, source
    InvitedVendor.create!(udprn: @udprn, email: vendor_email, agent_id: @agent_id.to_i, source: Vendor::INVITED_FROM_CONST[:family] )

    return response, status
  end

  def verify_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    assigned_agent = Agents::Branches::AssignedAgent.where(email: assigned_agent_email).first
    branch = Agents::Branches::AssignedAgent.where(id: @agent_id.to_i).last.branch
    vendor = Vendor.where(email: vendor_email).last
    if assigned_agent
      property_attrs[:agent_id] = assigned_agent.id
      property_attrs[:agent_status] = 2
      property_attrs[:vendor_id] = vendor.id if vendor
      assigned_agent_present = true
    end
    property_id = @udprn
    property_service = PropertyService.new(property_id)
    response, status = property_service.update_details(property_attrs)
    Agents::Branches::AssignedAgent.find(@agent_id).send_vendor_email(vendor_email, @udprn, assigned_agent_present, assigned_agent_email)

    
    ### Add this vendor to invited vendors table, source
    InvitedVendor.create!(udprn: @udprn, email: vendor_email, agent_id: @agent_id.to_i, source: Vendor::INVITED_FROM_CONST[:crawled] )

    return response, status
  end
end

