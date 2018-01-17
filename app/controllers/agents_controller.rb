class AgentsController < ApplicationController
  around_action :authenticate_agent, only: [ :branch_info_for_location, :invite_vendor, :create_agent_without_password, :add_credits,
                                             :branch_specific_invited_agents, :credit_history, :subscribe_premium_service, :remove_subscription,
                                             :manual_property_leads, :invited_vendor_history, :missing_sale_price_properties_for_agents, 
                                             :inactive_property_credits, :crawled_property_details, :verify_manual_property_from_agent,
																						 :claim_property ]
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
                                              :password, :provider, :uid, :oauth_token, :oauth_expires_at, :invited_agents]}},
                                    except: [:verification_hash, :invited_agents])
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
      invited_agents = branch.invited_agents
      new_agents = (JSON.parse(other_agents) rescue [])
      new_agent_emails = new_agents.map{ |t| t['email'] }
      existing_emails = Agents::Branches::AssignedAgent.where(email: new_agent_emails).pluck(:email).uniq
      missing_emails = new_agent_emails - existing_emails
      branch.invited_agents = new_agents.select{ |t| missing_emails.include?(t['email']) }
      branch.send_emails
      branch.invited_agents = branch.invited_agents + invited_agents
      if branch.save
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
    agent = @current_user
    vendor_email = params[:vendor_email]
    invited_vendor = InvitedVendor.where(email: vendor_email).where(agent_id: agent.id).last
    if invited_vendor
      invited_vendor.update_attributes(update_at: Time.now)
      agent.send_vendor_email(vendor_email, udprn)
    end
    render json: {message: 'Message sent successfully'}, status: 200
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
    udprn = params[:udprn].to_i
    agent_id = params[:agent_id].to_i
    property_status_type = params[:property_status_type]
    response, status = PropertyService.new(udprn).update_details({ property_status_type: property_status_type, verification_status: true, agent_id: agent_id, agent_status: 2 })
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
    pictures = params[:pictures]
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

    if pictures.is_a?(Array) && pictures.length > 0 && pictures.all?{ |t| t.has_key?('priority') && t.has_key?('url') && t.has_key?('description') }
      property_attrs[:pictures] = pictures
    end
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
    agent = @current_user
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
      properties = Agents::Branches::CrawledProperty.where(branch_id: branch_id).select([:id, :postcode, :image_urls, :stored_response, :additional_details, :udprn]).where.not(postcode: nil).limit(page_size).offset(page_no*page_size).order('created_at asc')
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
        new_row['udprn'] = property.udprn
        postcode = property.postcode
        response.push(new_row)
        postcodes = postcodes + "," + postcode
      end

      query = TestUkp
      where_query = postcodes.split(',').map{ |t| t.split(' ').join('') }.map{ |t| "(to_tsvector('simple'::regconfig, postcode)  @@ to_tsquery('simple', '#{t}'))" }.join(' OR ')
      results = TestUkp.connection.execute(query.where(where_query).select([:udprn, :postcode]).limit(1000).to_sql).to_a
      udprns = results.map{ |t| t['udprn'] }
      ### TODO: USE OF BULK DETAILS API HERE
      bulk_results = PropertyService.bulk_details(udprns)
      nullable_attrs = [:building_name, :building_number, :sub_building_name, :organisation_name, :department_name, :dependent_locality, :thoroughfare_descripion, :dependent_thoroughfare_description]
      bulk_results.each{ |result| nullable_attrs.each{ |attr| result[attr] ||= nil } }
      #results = Uk::Property.where(postcode: postcodes.split(',')).where(indexed: false).select([:building_name, :building_number, :sub_building_name, :organisation_name, :department_name, :postcode, :udprn, :post_town, :county]).select('dl as dependent_locality').select('td as thoroughfare_descripion').select('dtd as dependent_thoroughfare_description').limit(1000)
      logged_postcodes = []
      #Rails.logger.info(results.as_json)
      response.each do |each_crawled_property_data|
        if !each_crawled_property_data['udprn'] 
          matching_udprns = bulk_results.select{ |t| t[:postcode] == each_crawled_property_data['post_code'] && t[:property_status_type].nil?  }
          each_crawled_property_data['matching_properties'] = matching_udprns
          each_crawled_property_data['last_email_sent'] = nil
          each_crawled_property_data['vendor_email'] = nil
          each_crawled_property_data['is_vendor_registered'] = false
        else
          matching_udprns = each_crawled_property_data['udprn']
          details = PropertyDetails.details(matching_udprns)[:_source]
          each_crawled_property_data['matching_properties'] = [ matching_udprns ]
          each_crawled_property_data['address'] = details[:address]
          invited_vendor = InvitedVendor.where(agent_id: agent.id).where(udprn: matching_udprns).last
          each_crawled_property_data['last_email_sent'] = invited_vendor.created_at if invited_vendor
          each_crawled_property_data['vendor_email'] = invited_vendor.email if invited_vendor
          each_crawled_property_data['is_vendor_registered'] = Vendor.where(email: invited_vendor.email).last.nil? if invited_vendor
        end
        each_crawled_property_data['udprn'] = each_crawled_property_data['udprn'].to_i
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
    agent = @current_user
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
  rescue Exception => e 
    status = 400
    render json: { message: "#{e.message}" } , status: status
  end

  ### Adds credits  to the agents account
  ### The agent having the email will have to reset the password
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/agents/credits/add' -d '{ "stripeEmail" : "abhiuec@gmail.com", "stripeToken":"tok_19WlE9AKL3KAwfPBkWwgTpqt", "credits" : 100, "udprn":23840421 }'
  def add_credits
    agent = @current_user
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
  end

  ### Invited agents history for branches
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/agents/list/invited/agents'
  def branch_specific_invited_agents
    agent = @current_user
    branch_id = agent.branch_id
    invited_agents = InvitedAgent.where(branch_id: branch_id).select([:email, :created_at])
    render json: invited_agents, status: 200
  end

  ### Credits history
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/agents/credits/history'
  def credit_history
    agent = @current_user
    page_size = 20
    offset = params[:page].to_i*page_size
    payments = Stripe::Payment.where(entity_type: Stripe::Payment::USER_TYPES['Agent'], entity_id: agent.id).order('created_at DESC').limit(page_size).offset(offset)
    render json: { payments: payments }, status: 200
  end

  ### Agents api for submitting agent card info when subscribing to a premium service
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/agents/subscribe/premium/service' -d '{ "stripeEmail" : "email", "stripeToken" : "token" }'
  def subscribe_premium_service
    agent = @current_user
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
        agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(stripe_customer_id: event.data.object.customer).last
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
    agent = @current_user
    customer_id = agent.stripe_customer_id
    customer = Stripe::Customer.retrieve(customer_id)
    subscription.delete
    render json: { message: 'Unsubscribed succesfully' }, status: 200
  end

  ### Shows the leads for the personal properties claimed by the agent
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/manual/properties/leads'
  def manual_property_leads
    agent = @current_user
    #if true
    leads = Agents::Branches::AssignedAgent.find(agent.id).personal_claimed_properties
    render json: leads, status: 200
  end

  ### Shows the local branches to the vendor or a developer(pseudo vendor for a new property)
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/branches/list/:location
  def branch_info_for_location
    vendor = user_valid_for_viewing?('Vendor', ['Vendor', 'Agent'])
    #vendor = user_valid_for_viewing?('Agent')
    ### Either a vendor or a premium developer
    if !vendor.nil? && (vendor.class.to_s == 'Vendor' || (vendor.class.to_s == 'Agents::Branches::AssignedAgent' && vendor.is_developer ))
    #if true
      count = Agents::Branch.unscope(where: :is_developer).where(district: params[:location]).count
      #results = Agents::Branch.unscope(where: :is_developer).where(district: params[:location]).limit(20).offset(20*(params[:p].to_i)).map do |branch|
      results = Agents::Branch.unscope(where: :is_developer).where(district: params[:location]).map do |branch|
        agent_count = Agents::Branches::AssignedAgent.where(branch_id: branch.id).count
        agent_count == 0 ? agent_count = 0 : agent_count -= 1
        {
          logo: branch.image_url,
          name: branch.name,
          address: branch.address,
          phone_number: branch.phone_number,
          email: branch.email,
          website: branch.website,
          branch_id: branch.id,
          agent_count: agent_count
        }
      end
      render json: { branches: results, count: count }, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end
  
  ### Details of the agent who invited the vendor for that property
  ### curl -XGET 'http://properties/agent/details/:agent_id'
  def manual_agent_details
    vendor = user_valid_for_viewing?('Vendor')
    if !vendor.nil?
      agent_id = Agents::Branches::AssignedAgents::Lead.where(property_id: params[:udprn].to_i).first.agent_id
      details = Agents::Branches::AssignedAgent.find(agent_id).details
      render json: details, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### History of properties which have been manually invitedby the agents
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/properties/history/invited'
  def invited_vendor_history
    agent = @current_user
    results = []
    InvitedVendor.where(agent_id: agent.id).where(source: Vendor::INVITED_FROM_CONST[:family]).order('created_at DESC').each do |invited_vendor|
      udprn = invited_vendor.udprn
      details = PropertyDetails.details(udprn)[:_source]
      result = {
        beds: details[:beds],
        baths: details[:baths],
        receptions: details[:receptions],
        vendor_email: invited_vendor.email,
        property_type: details[:property_type],
        address: details[:address],
        last_email_sent: invited_vendor.created_at,
        is_vendor_registered: Vendor.where(email: invited_vendor.email).last.nil?
      }
      results.push(result)
    end
    render json: results, status: 200
  end

  ### List of properties which have been won by the agent, to be show for filling sale price
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/properties/quotes/missing/price'
  def missing_sale_price_properties_for_agents
    agent = @current_user
    #if true
      won_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
      quotes_won = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent.id, status: won_status).pluck(:property_id)
      api = PropertySearchApi.new(filtered_params: { not_exists: 'sale_price', agent_id: agent.id, results_per_page: 200 })
      api = api.filter_query
      result, status = api.filter
      if status.to_i == 200
        render json: result, status: status
      else
        render json: { message: 'Something wrong happened' }, status: 400
      end
  end

  ### Provide the credits which will be charged, if the agent makes an inactive property closed_won
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/inactive/property/credits/53831459?buyer_id=331'
  def inactive_property_credits
    agent = @current_user
    udprn = params[:udprn].to_i
    details = PropertyDetails.details(udprn)[:_source]
    buyer_id = params[:buyer_id].to_i
    offer_price = Evemt.where(buyer_id: buyer_id, udprn: udprn).last.offer_price
    credits = ((Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(offer_price.to_f)).to_i/Agents::Branches::AssignedAgent::PER_CREDIT_COST)
    has_required_credits = (agent.credit >= credits)
    render json: { credits: credits, has_required_credits: has_required_credits, agent_credits: agent.credit }, status: 200
  end

  ### Get all the details of the crawled property
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/details/property/:property_id'
  def crawled_property_details
    agent = @current_user
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
  end

  #### When an agent click the claim to a property, the agent gets a chance to visit
  #### the picture. The claim needs to be frozen and the property is no longer available
  #### for claiming.
  #### curl -XPOST -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/events/property/claim/4745413' 
  def claim_property
    agent = @current_user
    invited_vendor_emails = InvitedVendor.where(agent_id: agent.id).where(source: Vendor::INVITED_FROM_CONST[:family]).pluck(:email).uniq
    registered_vendor_count = Vendor.where(email: invited_vendor_emails).count
    if registered_vendor_count >= Agents::Branches::AssignedAgent::MIN_INVITED_FRIENDS_FAMILY_VALUE
      if agent.credit >= Agents::Branches::AssignedAgent::LEAD_CREDIT_LIMIT
      #if true
        property_service = PropertyService.new(params[:udprn].to_i)
        message, status = property_service.claim_new_property(params[:agent_id].to_i)
        render json: { message: message }, status: status
      else
        render json: { message: "Credits possessed for leads #{agent.credit},  not more than #{Agents::Branches::AssignedAgent::LEAD_CREDIT_LIMIT} " }, status: 401
      end
    else
      render json: { message: "Invited friends family below the minimum value #{Agents::Branches::AssignedAgent::MIN_INVITED_FRIENDS_FAMILY_VALUE}" }, status: 400
    end
  end

  #### On demand quicklink for all the properties of agents, or group or branch or company
  #### To get list of properties for the concerned agent
  #### curl -XGET 'http://localhost/agents/properties?agent_id=1234'
  #### Filters on property_for, ads
  def detailed_properties
    cache_parameters = [ :agent_id, :property_status_type, :verification_status, :ads , :count, :old_stats_flag].map{ |t| params[t].to_s }
    cache_response(params[:agent_id].to_i, cache_parameters) do
      response = {}
      results = []
      count = params[:count].to_s == 'true'
      old_stats_flag = params[:old_stats_flag].to_s == 'true'

      unless params[:agent_id].nil?
        #### TODO: Need to fix agents quotes when verified by the vendor
        agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: params[:agent_id].to_i).select([:id, :is_premium]).first
        if agent
          old_stats_flag = params[:old_stats_flag].to_s == 'true'
          search_params = { limit: 10000}
          search_params[:agent_id] = params[:agent_id].to_i
          property_status_type = params[:property_status_type]

          search_params[:property_status_type] = params[:property_status_type] if params[:property_status_type]
          search_params[:verification_status] = true if params[:verification_status] == 'true'
          search_params[:verification_status] = false if params[:verification_status] == 'false'

          #### Buyer filter
          if params[:buyer_id] && agent.is_premium
            buyer = PropertyBuyer.where(id: params[:buyer_id]).select(:vendor_id).first
            vendor_id = buyer.vendor_id if buyer
            vendor_id ||= nil
            search_params[:vendor_id] = vendor_id if vendor_id
          end

          ### Location filter
          if agent.is_premium && params[:hash_str]
            search_params[:hash_str] = params[:hash_str]
            search_params[:hash_type] = 'Text'
          end

          property_ids = []
          api = PropertySearchApi.new(filtered_params: search_params)
          api.modify_filtered_params
          api.apply_filters

          ### THIS LIMIT IS THE MAXIMUM. CAN BE BREACHED IN AN EXCEPTIONAL CASE
          api.query[:size] = 10000
          udprns, status = api.fetch_udprns

          ### Get all properties for whom the agent has won leads
          property_ids = udprns.map(&:to_i).uniq

          ### If ads filter is applied
          ad_property_ids = PropertyAd.where(property_id: property_ids).pluck(:property_id) if params[:ads].to_s == 'true' || params[:ads].to_s == 'false'

          property_ids = ad_property_ids if params[:ads].to_s == 'true'
          property_ids = property_ids - ad_property_ids if params[:ads].to_s == 'false'
          results = []
          #Rails.logger.info("property ids found for detailed properties (agent) = #{property_ids}")
          if agent.is_premium && count
            results = property_ids.uniq.count
          else
            results = property_ids.uniq.map { |e| Enquiries::AgentService.push_events_details(PropertyDetails.details(e), agent.is_premium, old_stats_flag) }
            vendor_ids = []
            vendor_id_property_map = {}
            results.each_with_index do |t, index|
              results[index][:ads] = (PropertyAd.where(property_id: t[:udprn]).count > 0) 
              vendor_ids.push(results[index][:vendor_id])
              vendor_id_property_map[results[index][:vendor_id].to_i] ||= []
              vendor_id_property_map[results[index][:vendor_id].to_i].push(index)
            end

            buyers = PropertyBuyer.where(vendor_id: vendor_ids.uniq.compact).select([:status, :buying_status, :vendor_id])

            buyers.each do |buyer|
              indices = vendor_id_property_map[buyer.vendor_id]
              indices.each do |index|
                results[index][:buyer_status] = PropertyBuyer::REVERSE_STATUS_HASH[buyer.status]
                results[index][:buying_status] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer.buying_status]
              end

            end

            vendor_id_property_map = {}

          end

          response = (!results.is_a?(Fixnum) && results.empty?) ? {"properties" => results, "message" => "No properties to show"} : {"properties" => results}
        else
          render json: { message: 'Agent id not found in the db'}, status: 400
        end
        #Rails.logger.info "Sending results for detailed properties (agent) => #{results.inspect}"
      else
        response = { message: 'Agent ID mandatory for getting properties' }
      end
      #Rails.logger.info "Sending response for detailed properties (agent) => #{response.inspect}"
      render json: response, status: 200
    end
  end



  private

  def user_valid_for_viewing?(klass, klasses=[])
    if !klasses.empty?
      result = nil
      klasses.each do |klass|
        result ||= AuthorizeApiRequest.call(request.headers, klass).result
      end
      result
    else
      AuthorizeApiRequest.call(request.headers, klass).result
    end
  end

  def authenticate_agent
    if user_valid_for_viewing?('Agent')
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  private

  def user_valid_for_viewing?(klass, klasses=[])
    if !klasses.empty?
      result = nil
      klasses.each do |klass|
        result ||= AuthorizeApiRequest.call(request.headers, klass).result
      end
      @current_user = result
      result
    else
      @current_user = AuthorizeApiRequest.call(request.headers, klass).result
    end
  end

end
