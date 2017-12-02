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

  #### Information about branches for this district
  #### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo"  'http://localhost/branches/list/:district'
  def list_branches
    vendor = user_valid_for_viewing?('Vendor')
    if !vendor.nil?
      Rails.logger.info(params[:district])
      branch_list = Agents::Branch.where(district: params[:district]).select([:id, :name]) 
      render json: branch_list, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Gets the last valuation info done for a udprn
  ### curl -XGET 'http://localhost/10966183/valuations/last/details'
  def last_valuation_details
    udprn = params[:udprn].to_i
    fields = [:agent_name, :agent_name, :agent_id, :agent_mobile]
    event = Event.where(event: Trackers::Buyer::EVENTS[:valuation_change])
                .where.not(property_status_type: Trackers::Buyer::PROPERTY_STATUS_TYPES['Rent'])
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
    quotes = AgentApi.new(params[:udprn].to_i, params[:agent_id].to_i).calculate_quotes
    render json: quotes, status: 200
  end

  ### Details of the agent
  ### curl -XGET 'http://localhost/agents/agent/1234'
  def assigned_agent_details
    assigned_agent_id = params[:assigned_agent_id]
    assigned_agent = Agents::Branches::AssignedAgent.find(assigned_agent_id)
    agent_details = assigned_agent.as_json(methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at, :invited_agents])
    agent_details[:company_id] = assigned_agent.branch.agent_id
    agent_details[:group_id] = assigned_agent.branch.agent.group_id
    agent_details[:domain_name] = assigned_agent.branch.domain_name
    render json: agent_details, status: 200
  end

  ### Details of the branch
  ### curl -XGET 'http://localhost/agents/branch/9851'
  def branch_details
    branch_id = params[:branch_id]
    branch = Agents::Branch.find(branch_id)
    branch_details = branch.as_json(include: {assigned_agents: {methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at, :invited_agents]}}, except: [:verification_hash, :invited_agents])
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
  rescue Exception => e
    render json: { message: 'Branch details not found', details: params }, status: 400
  end

  #### Invite the other agents to register
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/agents/invite' -d '{"branch_id" : 9851, "invited_agents" : "\[ \{ \"branch_id\" : 9851, \"company_id\" : 6290, \"email\" : \"test@prophety.co.uk\" \} ]" }'
  def invite_agents_to_register
    agent_id = params[:branch_id].to_i
    branch = Agents::Branch.where(id: agent_id).last
    if branch
      other_agents = params[:invited_agents]
      branch.invited_agents = branch.invited_agents + (JSON.parse(other_agents) rescue [])
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
    agent.first_name = agent_params['first_name'] if agent_params['first_name']
    agent.last_name = agent_params['last_name'] if agent_params['last_name']
    agent.email = agent_params['email'] if agent_params['email']
    agent.title = agent_params['title'] if agent_params['title']
    agent.mobile = agent_params['mobile'] if agent_params['mobile']
    agent.image_url = agent_params['image_url'] if agent_params['image_url']
    agent.branch_id = agent_params['branch_id'] if agent_params['branch_id']
    agent.password = agent_params['password'] if agent_params['password']
    agent.office_phone_number = agent_params['office_phone_number'] if agent_params['office_phone_number']
    agent.mobile_phone_number = agent_params['mobile_phone_number'] if agent_params['mobile']
    agent.save!
    AgentUpdateWorker.new.perform(agent.id)
    ### TODO: Update all properties containing this agent
    update_hash = { agent_id: agent_id }
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
  ### curl  -XPOST -H  "Content-Type: application/json"  'http://localhost/agents/23/udprns/10968961/verify' -d '{ "assigned_agent_id": 25, "vendor_email" : "test@prophety.co.uk" }'
  def invite_vendor
    udprn = params[:udprn].to_i
    original_agent = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i)
    assigned_agent = Agents::Branches::AssignedAgent.find(params[:assigned_agent_id].to_i)
    if original_agent.branch_id == assigned_agent.branch_id
      agent_id = params[:assigned_agent_id].to_i
      vendor_email = params[:vendor_email]
      Agents::Branches::AssignedAgent.find(agent_id).send_vendor_email(vendor_email, udprn)
      render json: {message: 'Message sent successfully'}, status: 200
    else
      raise 'Branch id doesnt match'
    end
  rescue Exception => e
   render json: {message: "#{e.message} " }, status: 400
  end


  ### Get the agent info who sent the mail to the vendor
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/invite/udprns/10968961/agents/info?verification_hash=$2a$10$rPk93fpnhYE6lnaUqO/mquXRFT/65F7ab3iclYAqKXingqTKOcwni' -d '{ "password" : "new_password" }'
  def info_for_agent_verification
    verification_hash = params[:verification_hash]
    udprn = params[:udprn]
    hash_obj = VerificationHash.where(hash_value: verification_hash, udprn: udprn.to_i).last
    if hash_obj
      agent = Agents::Branches::AssignedAgent.where(id: hash_obj.entity_id).last
      if agent
        password = params[:password]
        agent.password = password
        agent.save!
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
    property_for = params[:property_for]
    property_for ||= 'Sale'
    property_status_type = params[:property_status_type]
    response, status = PropertyDetails.update_details(client, udprn, { property_status_type: property_status_type, verification_status: true, agent_id: agent_id, agent_status: 2 })
    response['message'] = "Agent verification successful." unless status.nil? || status!=200
    render json: response, status: status
  rescue Exception => e
    Rails.logger.info("VERIFICATION_FAILURE_#{e}")
    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Verify the property as the intended agent and udprn as the correct udprn.
  ### Done when the invited vendor(through email) verifies the property as his/her
  ### property and the agent as his/her agent.
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/udprns/10968961/verify' -d '{ "verified": true, "vendor_id":319 }'
  def verify_property_from_vendor
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    response, status = nil
    udprn = params[:udprn].to_i
    property_status_type = params[:property_status_type]
    details = { property_status_type: property_status_type }
    details[:beds] = params[:beds].to_i if params[:beds]
    details[:baths] = params[:baths].to_i if params[:baths]
    details[:receptions] = params[:receptions].to_i if params[:receptions]
    details[:property_type] = params[:property_type] if params[:property_type]
    details[:dream_price] = params[:dream_price].to_i if params[:dream_price]
    details[:claimed_on] = Time.now.to_s
    details[:vendor_id] = params[:vendor_id].to_i
    details[:verification_status] = true
    response, status = PropertyDetails.update_details(client, udprn, details)
    response['message'] = "Property verification successful." unless status.nil? || status!=200
    render json: response, status: status
  rescue Exception => e
    Rails.logger.info("VENDOR_PROPERTY_VERIFICATION_FAILURE_#{e}")
    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Verify the property's basic attributes and attach the crawled property to a udprn
  ### Done when the agent attaches the udprn to the property
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/agents/properties/10968961/verify' -d '{ "property_type" : "Barn conversion", "beds" : 1, "baths" : 1, "receptions" : 1, "property_id" : 340620, "agent_id": 1234, "vendor_email": "residentevil293@prophety.co.uk", "assigned_agent_email" :  "residentevil293@prophety.co.uk" }'
  def verify_property_through_agent
    udprn = params[:udprn].to_i
    agent_id = params[:agent_id].to_i
    agent_service = AgentService.new(agent_id, udprn)
    property_for = params[:property_for]
    property_for ||= 'Sale'
    property_status_type = nil
    property_for == 'Sale' ? property_status_type = 'Green' : property_status_type = 'Rent'
    property_attrs = {
      property_status_type: property_status_type,
      verification_status: false,
      property_type: params[:property_type],
      beds: params[:beds].to_i,
      baths: params[:baths].to_i,
      receptions: params[:receptions].to_i,
      property_id: params[:property_id].to_i,
      details_completed: false,
      claimed_on: Time.now.to_s,
      claimed_by: 'Agent'
    }
    vendor_email = params[:vendor_email]
    assigned_agent_email = params[:assigned_agent_email]
    ### Update udprn in crawled properties
    Agents::Branches::CrawledProperty.where(id: params[:property_id].to_i).last.update_attributes({udprn: udprn})
    PropertyService.new(udprn).attach_crawled_property_attrs_to_udprn
    agent_count = Agents::Branches::AssignedAgent.where(id: agent_id).count > 0
    raise StandardError, 'Branch and agent not found' if agent_count == 0
    response, status = agent_service.verify_crawled_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
    response['message'] = 'Property details updated.' unless status.nil? || status != 200
    render json: response, status: status
#  rescue Exception => e
#    Rails.logger.info("AGENT_PROPERTY_VERIFICATION_FAILURE_#{e.message}")
#    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Add manual property's basic attributes and attach the crawled property to a udprn
  ### Done when the agent attaches the udprn to the property
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/agents/properties/10968961/manual/verify' -d '{ "property_type" : "Barn conversion", "beds" : 1, "baths" : 1, "receptions" : 1, "agent_id": 1234, "vendor_email": "residentevil293@prophety.co.uk", "assigned_agent_email" :  "residentevil293@prophety.co.uk" }'
  def verify_manual_property_from_agent
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
      udprn = params[:udprn].to_i
      agent_id = agent.id
      agent_service = AgentService.new(agent_id, udprn)
      property_attrs = {
        property_status_type: 'Green',
        verification_status: false,
        property_type: params[:property_type],
        receptions: params[:receptions].to_i,
        beds: params[:beds].to_i,
        baths: params[:baths].to_i,
        details_completed: false,
        property_id: udprn,
        claimed_on: Time.now.to_s,
        claimed_by: 'Agent'
      }
      vendor_email = params[:vendor_email]
      assigned_agent_email = params[:assigned_agent_email]
      response, status = agent_service.verify_manual_property_from_agent(property_attrs, vendor_email, assigned_agent_email)
      response['message'] = "Property details updated." unless status.nil? || status!=200
      render json: response, status: status
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  #rescue Exception => e
  #  Rails.logger.info("AGENT_MANUAL_PROPERTY_VERIFICATION_FAILURE_#{e}")
  #  render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Verifies which address/udprn to the crawled properties for the agent
  ### curl  -XGET  'http://localhost/agents/25/udprns/attach/verify'
  def verify_udprn_to_crawled_property
    agent_id = params[:id].to_i
    agent = Agents::Branches::AssignedAgent.where(id: agent_id).last
    postcode = nil
    base_url = "https://s3-us-west-2.amazonaws.com/propertyuk/"
    response = []
    postcodes = ""
    page_no = params[:page].to_i rescue 0
    page_size = 20
    if agent
      branch_id = agent.branch_id
      properties = Agents::Branches::CrawledProperty.where(branch_id: branch_id).select([:id, :postcode, :image_urls, :stored_response, :additional_details, :udprn]).where.not(postcode: nil).where(udprn: nil).limit(page_size).offset(page_no*page_size).order('created_at asc')
      property_count = Agents::Branches::CrawledProperty.where(branch_id: branch_id).where.not(postcode: nil).where(udprn: nil).count
      assigned_agent_emails = Agents::Branches::AssignedAgent.where(branch_id: branch_id).pluck(:email)
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
        new_row['property_status_type'] = 'Green'
        new_row['assigned_agent_emails'] = assigned_agent_emails
        postcode = property.postcode
        response.push(new_row)
        postcodes = postcodes + "," + postcode
      end
      results = Uk::Property.where(postcode: postcodes.split(',')).where(indexed: false).select([:building_name, :building_number, :sub_building_name, :organisation_name, :department_name, :postcode, :udprn, :post_town, :county]).select('dl as dependent_locality').select('td as thoroughfare_descripion').select('dtd as dependent_thoroughfare_description').limit(1000)
      logged_postcodes = []
      #Rails.logger.info(results.as_json)
      response.each do |each_crawled_property_data|
        matching_udprns = results.select{ |t| t.postcode == each_crawled_property_data['post_code'] }
        # Rails.logger.info("HELLO") if !matching_udprns.empty?
        each_crawled_property_data['matching_properties'] = matching_udprns
      end
      render json: { response: response, property_count: property_count }, status: 200
    else
      render json: { message: 'Agent not found' }, status: 404
    end
  end

  ### Verifies which address/udprn to the crawled properties for the agent
  ### curl -XGET 'http://localhost/agents/rent/25/udprns/attach/verify'
  def verify_udprn_to_crawled_property_for_rent
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
      branch.domain_name = branch_details[:domain_name] if branch_details[:domain_name] && !branch_details[:domain_name].blank?
      if branch.save!
        render json: { message: 'Branch edited successfully', details: branch.as_json(only: [:name, :address, :phone_number, :website, :image_url, :email, :domain_name]) }, status: 200
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
      group.image_url = group_details[:image_url] if group_details[:image_url] && !group_details[:image_url].blank?
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

  ### Creates a new agent with a randomized password
  ### The agent having the email will have to reset the password
  ### curl -XPOST -H "Content-Type: application/json"  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/add/:agent_id' -d '{ "first_name" : "Jack", "last_name" : "Daniels", "title" : "Mr.", "email" : "jack_daniels@prophety.co.uk", "mobile_number" : "876628921", "branch_id" : 1422 }'
  def create_agent_without_password
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
      response = {}
      agent_hash = {
        name: params[:first_name] + ' ' + params[:last_name],
        first_name: params[:first_name],
        last_name: params[:last_name],
        title: params[:title],
        branch_id: params[:branch_id],
        email: params[:email],
        mobile: params[:mobile_number],
        password: SecureRandom.hex(8)
      }
      response = Agents::Branches::AssignedAgent.create!(agent_hash)
      status = 201
      render json: response, status: status
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  rescue Exception => e 
    status = 400
    render json: { message: "#{e.message}" } , status: status
  end

  ### Adds credits  to the agents account
  ### The agent having the email will have to reset the password
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/agents/credits/add' -d '{ "stripeEmail" : "abhiuec@gmail.com", "stripeToken":"tok_19WlE9AKL3KAwfPBkWwgTpqt", "credits" : 100, "udprn":23840421 }'
  def add_credits
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
      begin
        customer = Stripe::Customer.create(
          email: params[:stripeEmail],
          card: params[:stripeToken]
        )
        amount = Agents::Branches::AssignedAgent::PER_CREDIT_COST*params[:credit].to_i*100 ### In pences
        charge = Stripe::Charge.create(
          customer: customer.id,
          amount: amount,
          description: 'Add credit to agents Stripe customer',
          currency: 'GBP'
        )
        agent.credit = agent.credit + params[:credit].to_i
        agent.save!
        Stripe::Payment.create!(entity_type: 'Agents::Branches::AssignedAgent', entity_id: agent.id, amount: amount, charge_id: charge.id, udprn: params[:udprn].to_i)
        render json: { message: 'Successfully added credits', credits: agent.credit, credits_bought: params[:credit].to_i }, status: 200
      rescue Exception => e
        re = Stripe::Refund.create(
          charge: charge.id,
          amount: value
        )
        Rails.logger.info("REFUND_INITIATED_#{e.message}_#{agent}_#{params[:credit]}")
        render json: { message: 'Unsuccessful in adding credits' }, status: 401
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Credits history
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/agents/credits/history'
  def credit_history
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
      page_size = 20
      offset = params[:page].to_i*page_size
      payments = Stripe::Payment.where(entity_type: Stripe::Payment::USER_TYPES['Agent'], entity_id: agent.id).order('created_at DESC').limit(page_size).offset(offset)
      render json: { payments: payments }, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Agents api for submitting agent card info when subscribing to a premium service
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/agents/subscribe/premium/service' -d '{ "stripeEmail" : "email", "stripeToken" : "token" }'
  def subscribe_premium_service
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
      sig_header = request.env['HTTP_STRIPE_SIGNATURE']
      payload = request.body.read
      begin
        # Create the customer in Stripe
        customer = Stripe::Customer.create(
          email: params[:stripeEmail],
          card: params[:stripeToken],
          plan: 'agent_monthly_premium_package'
        )
        stripe_subscription = customer.subscriptions.create(:plan => 'agent_monthly_premium_package')
        agent.is_premium = true
        agent.stripe_customer_id = customer.id
        agent.premium_expires_at = 1.month.from_now.to_date
        agent.save!
        render json: { message: 'Created a monthly subscription for premium service' }, status: 200
      rescue JSON::ParserError => e
        # Invalid payload
        status 400
        render json: { message: 'JSON parser error' }, status: 400
      rescue Stripe::SignatureVerificationError => e
        # Invalid signature
        render json: { message: 'Invalid Signature' }, status: 400
      rescue Exception => e
        Rails.logger.info(e.message)
        render json: { message: 'Unable to create Stripe customer and charge. Please retry again' }, status: 400
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Info about the premium charges monthly
  ### curl -XGET 'http://localhost/agents/premium/cost'
  def info_premium
    render json: { value: Agents::Branches::AssignedAgent::PREMIUM_COST }, status: 200
  end

  ### Stripe agents subscription recurring payment
  ### curl -XPOST  -H "Content-Type: application/json" 'http://localhost/agents/premium/subscription/process'
  def process_subscription
    event = Stripe::Event.retrieve(params['id'])
    case event.type
      when "invoice.payment_succeeded" #renew subscription
        agent = Agents::Branches::AssignedAgent.where(stripe_customer_id: event.data.object.customer).last
        if agent
          agent.premium_expires_at = 1.month.from_now.to_date
          agent.save!
        end
    end
    render status: :ok, json: 'success'
  end

  ### Stripe agents subscription recurring payment
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/premium/subscription/remove'
  def remove_subscription
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
      customer_id = agent.stripe_customer_id
      customer = Stripe::Customer.retrieve(customer_id)
      subscription.delete
      render json: { message: 'Unsubscribed succesfully' }, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Shows the leads for the personal properties claimed by the agent
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/manual/properties/leads'
  def manual_property_leads
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
    #if true
      leads = Agents::Branches::AssignedAgent.find(agent.id).personal_claimed_properties
      render json: leads, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Shows the leads for the personal properties claimed by the agent
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/branches/list/:location
  def branch_info_for_location
    vendor = user_valid_for_viewing?('Vendor')
    if !vendor.nil?
    #if true
      count = Agents::Branch.where(district: params[:location]).count
      results = Agents::Branch.where(district: params[:location]).limit(20).offset(20*(params[:p].to_i)).map do |branch|
        {
          logo: branch.image_url,
          name: branch.name,
          address: branch.address,
          phone_number: branch.phone_number,
          email: branch.email,
          website: branch.website,
          branch_id: branch.id
        }
      end
      render json: { branches: results, count: count }, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Get all the details of the crawled property
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" '/agents/details/property/:property_id'
  def crawled_property_details
    agent = user_valid_for_viewing?('Agent')
    if !agent.nil?
    #if true
      crawled_property = Agents::Branches::CrawledProperty.where(id: params[:property_id].to_i).last
      if crawled_property
        details = {}
        details[:beds] = crawled_property.stored_response['beds']
        details[:baths] = crawled_property.stored_response['baths']
        details[:receptions] = crawled_property.stored_response['receptions']
        details[:title] = crawled_property.stored_response['title']
        details[:assigned_agent_image_url] = crawled_property.stored_response['agent_logo']
        details[:assigned_agent_image_url] = crawled_property.stored_response['agent_logo']
        details[:opening_hours] = crawled_property.stored_response['opening_hours']
        details[:listing_category] = crawled_property.additional_details['listings_category']
        details[:price] = crawled_property.additional_details['price']
        details[:floorplan_url] = crawled_property.stored_response['floorplan_url']
        details[:property_type] = crawled_property.additional_details['property_type']
        details[:epc] = crawled_property.additional_details['has_epc']
        details[:total_area] = crawled_property.additional_details['size_sq_feet']
        details[:total_area] ||= (crawled_property.additional_details['size_sq_metres'].to_f*3.280).to_i if crawled_property.additional_details['size_sq_metres']
        details[:price_qualifier] = crawled_property.additional_details['price_qualifier']
        details[:property_style] = crawled_property.additional_details['listing_condition']
        details[:is_retirement_home] = crawled_property.additional_details['is_retirement_home']
        highlights = crawled_property.additional_details['property_highlights'].split('|') rescue []
        main_features = crawled_property.stored_response['features']
        main_features ||= []
        details[:additional_features] = main_features + highlights
        details[:description] = crawled_property.stored_response['description']
        render json: details, status: 200
      else
        render json: { message: 'Property does not exist' }, status: 400
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  private

  def user_valid_for_viewing?(klass)
    AuthorizeApiRequest.call(request.headers, klass).result
  end

end
