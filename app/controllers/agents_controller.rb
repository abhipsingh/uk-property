class AgentsController < ApplicationController
  ### Details of the branch
  ### curl -XGET 'http://localhost/agents/predictions?str=Dyn'
  def search
    klasses = ['Agent', 'Agents::Branch', 'Agents::Group', 'Agents::Branches::AssignedAgent']
    klass_map = {
      'Agent' => 'Company',
      'Agents::Branch' => 'Branch',
      'Agents::Group' => 'Group',
      'Agents::Branches::AssignedAgent' => 'Agent'
    }
    search_results = klasses.map { |e|  e.constantize.where("lower(name) LIKE ?", "#{params[:str].downcase}%").limit(10).as_json }
    results = []
    search_results.each_with_index do |result, index|
      new_row = {}
      new_row[:type] = klass_map[klasses[index]]
      new_row[:result] = result
      results.push(new_row)
    end
    render json: results, status: 200
  end

  ### Group by a district and calculate the number of agents and branches
  ### curl -XGET 'http://localhost/agents/info/10968961'
  def info_agents
    udprn = params[:udprn]
    details = PropertyDetails.details(udprn.to_i)
    district = details['_source']['district']
    count = Agents::Branches::AssignedAgent.joins(:branch).where('agents_branches.district = ?', district).count
    render json: count, status: 200
  end

  ### Gets the last valuation info done for a udprn
  ### curl -XGET 'http://localhost/10966183/valuations/last/details'
  def last_valuation_details
    udprn = params[:udprn].to_i
    fields = [:agent_name, :agent_name, :agent_id, :agent_mobile]
    event = Event.where(event: Trackers::Buyer::EVENTS[:valuation_change])
                .where(udprn: udprn)
                .order('created_at DESC')
                .select(fields)
                .select("message ->> 'current_valuation' as last_valuation")
                .select('created_at as last_valuation_date')
                .last
    if event
      render json: event, status: 200
    else
      details = PropertyDetails.details(udprn)['_source']
      response = {
        agent_name: details['assigned_agent_employee_name'],
        agent_id: details['agent_id'],
        last_valuation: details['current_valuation'],
        last_valuation_date: details['status_last_updated']
      }

      render json: response, status: 200
    end
  end

  def quotes_per_property
    quotes = AgentApi.new(params[:property_id].to_i, params[:agent_id].to_i).calculate_quotes
    render json: quotes, status: 200
  end

  ### Details of the agent
  ### curl -XGET 'http://localhost/agents/agent/1234'
  def assigned_agent_details
    assigned_agent_id = params[:assigned_agent_id]
    assigned_agent = Agents::Branches::AssignedAgent.find(assigned_agent_id)
    agent_details = assigned_agent.as_json(methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at])
    agent_details[:company_id] = assigned_agent.branch.agent_id
    agent_details[:group_id] = assigned_agent.branch.agent.group_id
    render json: agent_details, status: 200
  end

  ### Details of the branch
  ### curl -XGET 'http://localhost/agents/branch/9851'
  def branch_details
    branch_id = params[:branch_id]
    branch = Agents::Branch.find(branch_id)
    branch_details = branch.as_json(include: {assigned_agents: {methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at]}}, except: [:verification_hash])
    branch_details[:company_id] = branch.agent_id
    branch_details[:group_id] = branch.agent.group.id
    render json: branch_details, status: 200
  end

  ### Details of the company
  ### curl -XGET 'http://localhost/agents/company/6290'
  def company_details
    company_id = params[:company_id]
    company_details = Agent.find(company_id)
    company_details = company_details.as_json(include:  { branches: { include: { assigned_agents: {methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at]}}, except: [:verification_hash]}})
    render json: company_details, status: 200
  end

  ### Details of the group
  ### curl -XGET 'http://localhost/agents/group/1'
  def group_details
    group_id = params[:group_id]
    group = Agents::Group.find(group_id)
    group_details = group.as_json(include:  { companies: { include: { branches: { include: { assigned_agents: {methods: [:active_properties]}}}}}})
    render json: group_details, status: 200
  end

  ### Add new agent details to exisiting or create a new agent
  ### agent_id is null or not null depending upon if its a new agent or not
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/agents/register' -d '{ "branch_id" : 9851, "company_id" : 6290, "group_id" : 1, "group_name" :"Dynamic Group", "company_name" : "Dynamic Property Management", "branch_name" : "Dynamic Property Management", "branch_address" : "18 Hope Street, Crook, DL15 9HS", "branch_phone_number" : "9988776655", "branch_email" : "df@fg.com", "branch_website" : "www.dmg.com", "verification_hash" : "$2a$10$hdCZNKpM2VXH15h4TZKrLeJOH9ZptIZjK0jCE/LhD39Xs6DYYz9nS" }'
  #### Successful
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/agents/register' -d '{ "branch_id" : 9851, "company_id" : 6290, "group_id" : 1, "group_name" :"Dynamic Group", "company_name" : "Dynamic Property Management", "branch_name" : "Dynamic Property Management", "branch_address" : "18 Hope Street, Crook, DL15 9HS", "branch_phone_number" : "9988776655", "branch_email" : "df@fg.com", "branch_website" : "www.dmg.com", "verification_hash" : "$2a$10$E0NsNocTd0getkV7h8GcFuwLlekcyUugcEg9lVXIzADRskrdcyYOu" }'
  #### Unsuccessful
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/agents/register' -d '{ "branch_id" : 9851, "company_id" : 6290, "group_id" : 1, "group_name" :"Dynamic Group", "company_name" : "Dynamic Property Management", "branch_name" : "Dynamic Property Management", "branch_address" : "18 Hope Street, Crook, DL15 9HS", "branch_phone_number" : "9988776655", "branch_email" : "df@fg.com", "branch_website" : "www.dmg.com", "verification_hash" : "$2a$10$E0NsNocTd0getkV7h8GcFuwLlekcyUugcEg9lVXIzADRskrdcyYOu1" }
  def add_agent_details
    branch_id = params[:branch_id].to_i
    branch = Agents::Branch.where(id: branch_id).first
    company = branch.agent
    group = company.group
    branch.name = params[:branch_name]
    branch.address = params[:branch_address]
    branch.email = params[:branch_email]
    branch.phone_number = params[:branch_phone_number]
    branch.website = params[:branch_website]
    group.name = params[:group_name]
    company.name = params[:company_name]
    verification_hash = params[:verification_hash]
    if branch.verify_hash(verification_hash) && company.save! && group.save! && branch.save!
      render json: { message: 'Branch details updated successfully', details: branch }, status: 201
    else
      render json: { message: 'Branch details not saved successfully', details: params }, status: 400
    end
  rescue 
    render json: { message: 'Branch details not found', details: params }, status: 400
  end

  #### Invite the other agents to register
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/agents/invite' -d '{"branch_id" : 9851, "invited_agents" : "\[ \{ \"branch_id\" : 9851, \"company_id\" : 6290, \"email\" : \"test@prophety.co.uk\" \} ]" }'
  def invite_agents_to_register
    agent_id = params[:branch_id].to_i
    branch = Agents::Branch.where(id: agent_id).last
    if branch
      other_agents = params[:invited_agents]
      branch.invited_agents = JSON.parse(other_agents)
      if branch.save
        branch.send_emails
        render json: { message: 'Branch with given emails invited' }, status: 200
      else
        render json: { message: 'Server error' }, status: 400
      end
    else
      render json: { message: 'Branch with given branch_id doesnt exist' }, status: 400
    end
  end

  ### An api to edit the agent details
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost/agents/23/edit' -d '{ "agent" : { "name" : "Jackie Bing", "email" : "jackie.bing@friends.com", "mobile" : "9873628232", "password" : "1234567890", "branch_id" : 9851, "office_phone_number" : "9876543210", "mobile_phone_number": "7896543219" } }'
  def edit
    agent_id = params[:id].to_i
    agent = Agents::Branches::AssignedAgent.find(agent_id)
    agent_params = params[:agent].as_json
    agent.name = agent_params['name'] if agent_params['name']
    agent.email = agent_params['email'] if agent_params['email']
    agent.title = agent_params['title'] if agent_params['title']
    agent.mobile = agent_params['mobile'] if agent_params['mobile']
    agent.image_url = agent_params['image_url'] if agent_params['image_url']
    agent.branch_id = agent_params['branch_id'] if agent_params['branch_id']
    agent.password = agent_params['password'] if agent_params['password']
    agent.office_phone_number = agent_params['office_phone_number'] if agent_params['office_phone_number']
    agent.mobile_phone_number = agent_params['mobile_phone_number'] if agent_params['mobile']
    render json: {message: 'Updated successfully', details: agent}, status: 200  if agent.save!
  rescue 
    render json: {message: 'Failed to Updated successfully'}, status: 200
  end

  ### Shows the udprns in the branch_id which are not verified and Green along with 
  ###  email ids and ids of the assigned agents
  ### curl  -XGET  'http://localhost/agents/23/udprns/verify'
  def verify_udprns
    agent_id = params[:id].to_i
    agent = Agents::Branches::AssignedAgent.where(id: agent_id).first
    if agent && agent.branch
      branch = agent.branch
      district = branch.district
      filtered_params = {}
      filtered_params[:district] = district
      filtered_params[:property_status_type] = 'Green'
      filtered_params[:verification_status] = false
      search_api = PropertySearchApi.new(filtered_params: filtered_params)
      search_api.apply_filters
      body, status = search_api.fetch_data_from_es
      agents = Agents::Branches::AssignedAgent.where(branch_id: branch.id).select([:email, :id])
      render json: { properties: body, agents: agents }, status: 200
    else
      render json: { message: 'Agent not found with the given id' }, status: 400
    end
  end

  ### Invite vendor to verify the udprn
  ### curl  -XPOST -H  "Content-Type: application/json"  'http://localhost/agents/23/udprns/10968961/verify' -d '{ "vendor_email" : "test@prophety.co.uk" }'
  def invite_vendor
    udprn = params[:udprn].to_i
    agent_id = params[:agent_id].to_i
    vendor_email = params[:vendor_email]
    Agents::Branches::AssignedAgent.find(agent_id).send_vendor_email(vendor_email, udprn)
    render json: {message: 'Message sent successfully'}, status: 200
  #rescue Exception
  #  render json: {message: 'Message failed sending'}, status: 400
  end


  ### Get the agent info who sent the mail to the vendor
  ### curl  -XGET -H  "Content-Type: application/json" 'http://localhost/vendors/invite/udprns/10968961/agents/info?verification_hash=$2a$10$4hIPKrtj8tWQb1oTOcvnnur8Jsr8Wnin30fS7IULXKJWiIl.aTc6q'
  def info_for_agent_verification
    verification_hash = params[:verification_hash]
    udprn = params[:udprn]
    hash_obj = VerificationHash.where(hash_value: verification_hash, udprn: udprn.to_i).last
    if hash_obj
      agent = Agents::Branches::AssignedAgent.where(id: hash_obj.entity_id).last
      if agent
        render json: { details: {agent_name: agent.name, agent_id: agent.id, agent_email: agent.email, udprn: udprn } }, status: 200
      else
        render json: { message: 'Agent not found' }, status: 400
      end
    else
      render json: { message: 'hash not found' }, status: 400
    end
  end

  ### Verify the agent as the intended agent and udprn as the correct udprn
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/udprns/10968961/agents/23/verify'
  def verify_agent
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    udprn = params[:udprn].to_i
    agent_id = params[:agent_id].to_i
    response, status = PropertyDetails.update_details(client, udprn, { property_status_type: 'Green', verification_status: true, agent_id: agent_id })
    response['message'] = "Agent verification successful." unless status.nil? || status!=200
    render json: response, status: status
  rescue Exception => e
    Rails.logger.info("VERIFICATION_FAILURE_#{e}")
    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Verify the property as the intended agent and udprn as the correct udprn.
  ### Done when the invited vendor(through email) verifies the property as his/her
  ### property and the agent as his/her agent.
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/udprns/10968961/verify' -d '{ verified: true }'
  def verify_property_from_vendor
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    response, status = nil
    udprn = params[:udprn].to_i
    if params[:verified].to_s == 'true'
      response, status = PropertyDetails.update_details(client, udprn, { property_status_type: 'Green', verification_status: true })
      response['message'] = "Property verification successful." unless status.nil? || status!=200
    else
      response['message'] = "Property verification unsuccessful. This incident will be reported" unless status.nil? || status!=200
      ### TODO: Take further action when the vendor rejects verification
    end
    render json: response, status: status
  rescue Exception => e
    Rails.logger.info("VENDOR_PROPERTY_VERIFICATION_FAILURE_#{e}")
    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Verify the property's basic attributes and attach the crawled property to a udprn
  ### Done when the agent attaches the udprn to the property
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/agents/properties/10968961/verify' -d '{ "property_type" : "Barn conversion", "beds" : 1, "baths" : 1, "receptions" : 1, "property_id" : 340620, "agent_id": 1234, "vendor_email": "residentevil293@prophety.co.uk", "assigned_agent_email" :  "residentevil293@prophety.co.uk" }'
  def verify_property_from_agent
    udprn = params[:udprn].to_i
    agent_id = params[:agent_id].to_i
    agent_service = AgentService.new(agent_id, udprn)
    property_attrs = {
      property_status_type: 'Green',
      verification_status: false,
      property_type: params[:property_type],
      receptions: params[:receptions].to_i,
      beds: params[:beds].to_i,
      baths: params[:baths].to_i,
      receptions: params[:receptions].to_i,
      property_id: params[:property_id].to_i,
      details_completed: true
    }
    vendor_email = params[:vendor_email]
    assigned_agent_email = params[:assigned_agent_email]
    agent_count = Agents::Branches::AssignedAgent.where(id: agent_id).count > 0
    raise StandardError, "Branch and agent not found" if agent_count == 0
    response, status = agent_service.verify_crawled_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    response['message'] = "Property details updated." unless status.nil? || status!=200
    render json: response, status: status
  rescue Exception => e
    Rails.logger.info("AGENT_PROPERTY_VERIFICATION_FAILURE_#{e}")
    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Add manual property's basic attributes and attach the crawled property to a udprn
  ### Done when the agent attaches the udprn to the property
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/agents/properties/10968961/manual/verify' -d '{ "property_type" : "Barn conversion", "beds" : 1, "baths" : 1, "receptions" : 1, "agent_id": 1234, "vendor_email": "residentevil293@prophety.co.uk", "assigned_agent_email" :  "residentevil293@prophety.co.uk" }'
  def verify_manual_property_from_agent
    udprn = params[:udprn].to_i
    agent_id = params[:agent_id].to_i
    agent_service = AgentService.new(agent_id, udprn)
    property_attrs = {
      property_status_type: 'Green',
      verification_status: false,
      property_type: params[:property_type],
      receptions: params[:receptions].to_i,
      beds: params[:beds].to_i,
      baths: params[:baths].to_i,
      receptions: params[:receptions].to_i,
      property_id: params[:property_id].to_i,
      details_completed: false
    }
    vendor_email = params[:vendor_email]
    assigned_agent_email = params[:assigned_agent_email]
    agent_count = Agents::Branches::AssignedAgent.where(id: agent_id).count > 0
    raise StandardError, "Branch and agent not found" if agent_count == 0
    response, status = agent_service.verify_manual_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    response['message'] = "Property details updated." unless status.nil? || status!=200
    render json: response, status: status
  rescue Exception => e
    Rails.logger.info("AGENT_MANUAL_PROPERTY_VERIFICATION_FAILURE_#{e}")
    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Verifies which address/udprn to the crawled properties for the agent
  ### curl  -XGET  'http://localhost/agents/25/udprns/attach/verify'
  def verify_udprn_to_crawled_property
    agent_id = params[:id].to_i
    agent = Agents::Branches::AssignedAgent.where(id: agent_id).last
    postcode = nil
    base_url = "https://s3-us-west-2.amazonaws.com/propertyuk/"
    response = []
    postcodes = []
    if agent
      branch_id = agent.branch_id
      properties = Agents::Branches::CrawledProperty.where(branch_id: branch_id).select([:id, :postcode, :image_urls, :stored_response, :additional_details]).where.not(postcode: nil)
      properties.each do |property|
        new_row = {}
        new_row['property_id'] = property.id
        new_row['beds'] = property.stored_response['beds']
        new_row['baths'] = property.stored_response['baths']
        new_row['receptions'] = property.stored_response['receptions']
        new_row['address'] = property.stored_response['address']
        new_row['image_urls'] = property.image_urls.map { |e| base_url + e }
        new_row['property_type'] = property.additional_details['property_type'] rescue nil
        new_row['post_code'] = property.postcode
        postcode = property.postcode.split(" ").join('')
        response.push(new_row)
        postcodes |= [postcode]
      end
      Rails.logger.info(postcodes)
      params_hash = { postcodes: postcodes, fields: "udprn,building_name,building_number,sub_building_name,post_code" }
      search_api = PropertySearchApi.new(filtered_params: params_hash)
      search_api.apply_filters
      body, status = search_api.fetch_data_from_es
      body.each do |each_doc|
        each_doc['building_name'] ||= nil
        each_doc['building_number'] ||= nil
        each_doc['sub_building_name'] ||= nil
      end
      response.each do |each_crawled_property_data|
        matching_udprns = body.select{ |t| t['post_code'] == each_crawled_property_data['post_code'] }
        each_crawled_property_data['matching_properties'] = matching_udprns
      end
      render json: { response: response }, status: 200
    else
      render json: { message: 'Agent not found' }, status: 404
    end
  end


  #### Edit details of a branch
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost/branches/9851/edit' -d '{ "branch" : { "name" : "Jackie Bing", "address" : "8 The Precinct, Main Road, Church Village, Pontypridd, HR1 1SB", "phone_number" : "9873628232", "website" : "www.google.com", "image_url" : "some random url", "email" : "a@b.com"  } }'
  def edit_branch_details
    branch = Agents::Branch.where(id: params[:id].to_i).last
    if branch
      branch_details = params[:branch]
      branch.name = branch_details[:name] if branch_details[:name] && !branch_details[:name].blank?
      branch.address = branch_details[:address] if branch_details[:address] && !branch_details[:address].blank?
      branch.phone_number = branch_details[:phone_number] if branch_details[:phone_number] && !branch_details[:phone_number].blank?
      branch.website = branch_details[:website] if branch_details[:website] && !branch_details[:website].blank?
      branch.image_url = branch_details[:image_url] if branch_details[:image_url] && !branch_details[:image_url].blank?
      branch.email = branch_details[:email] if branch_details[:email] && !branch_details[:email].blank?
      if branch.save!
        render json: { message: 'Branch edited successfully', details: branch.as_json(only: [:name, :address, :phone_number, :website, :image_url, :email]) }, status: 200
      else
        render json: { message: 'Branch not able to edit' }, status: 400
      end
    else
      render json: { message: 'Branch not found' }, status: 404
    end
  end


  #### Edit company details
  ### `curl -XPOST -H "Content-Type: application/json"  'http://localhost/companies/6290/edit' -d '{ "company" : { "name" : "Jackie Bing", "address" : "8 The Precinct, Main Road, Church Village, Pontypridd, HR1 1SB", "phone_number" : "9873628232", "website" : "www.google.com", "image_url" : "some random url", "email" : "a@b.com"  } }'`
  def edit_company_details
    company = Agent.where(id: params[:id].to_i).last
    if company
      company_details = params[:company]
      company.name = company_details[:name] if company_details[:name] && !company_details[:name].blank?
      company.image_url = company_details[:image_url] if company_details[:image_url] && !company_details[:image_url].blank?
      company.email = company_details[:email] if company_details[:email] && !company_details[:email].blank?
      company.phone_number = company_details[:phone_number] if company_details[:phone_number] && !company_details[:phone_number].blank?
      company.website = company_details[:website] if company_details[:website] && !company_details[:website].blank?
      company.address = company_details[:address] if company_details[:address] && !company_details[:address].blank?
      if company.save!
        render json: { message: 'Company edited successfully', details: company.as_json(only: [:name, :address, :phone_number, :website, :image_url, :email]) }, status: 200
      else
        render json: { message: 'Company not able to edit' }, status: 400
      end
    else
      render json: { message: 'Company details not found' }, status: 404
    end
  end

  #### Edit group details
  ### `curl -XPOST -H "Content-Type: application/json"  'http://localhost/groups/6292/edit' -d '{ "group" : { "name" : "Jackie Bing", "address" : "8 The Precinct, Main Road, Church Village, Pontypridd, HR1 1SB", "phone_number" : "9873628232", "website" : "www.google.com", "image_url" : "some random url", "email" : "a@b.com"  } }'`
  def edit_group_details
    group = Agents::Group.where(id: params[:id].to_i).last
    if group
      group_details = params[:group]
      group.name = group_details[:name] if group_details[:name] && !group_details[:name].blank?
      group.image_url = group_details[:image_url] if group[:image_url] && !group[:image_url].blank?
      group.email = group_details[:email] if group_details[:email] && !group_details[:email].blank?
      group.phone_number = group_details[:phone_number] if group_details[:phone_number] && !group_details[:phone_number].blank?
      group.website = group_details[:website] if group_details[:website] && !group_details[:website].blank?
      group.address = group_details[:address] if group_details[:address] && !group_details[:address].blank?
      if group.save!
        render json: { message: 'Group edited successfully', details: group.as_json(only: [:name, :address, :phone_number, :website, :image_url, :email]) }, status: 200
      else
        render json: { message: 'Group not able to edit' }, status: 400
      end
    else
      render json: { message: 'Group details not found' }, status: 404
    end
  end

  def test_view
    render "test_view"
  end

end
