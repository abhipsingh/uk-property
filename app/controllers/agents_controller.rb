class AgentsController < ApplicationController
  include CacheHelper

  around_action :authenticate_agent, only: [ :invite_vendor, :create_agent_without_password, :add_credits,
                                             :branch_specific_invited_agents, :credit_history, :subscribe_premium_service, :remove_subscription,
                                             :manual_property_leads, :invited_vendor_history, :missing_sale_price_properties_for_agents, 
                                             :inactive_property_credits, :crawled_property_details, :verify_manual_property_from_agent,
																						 :claim_property, :matching_udprns,  :list_of_properties, :invite_agents_to_register,
                                             :additional_agent_details_intercom, :agent_credit_info, :verify_manual_property_from_agent_non_f_and_f,
                                             :incomplete_list_of_properties, :unlock_agent, :send_emails_to_enquiry_producing_buyers,
                                             :enquiry_count_for_buyer_emails, :send_bulk_emails_to_buyers, :send_mailshots_to_properties,
                                             :mailshot_payment_history, :fetch_invited_properties_for_district, :agent_details, 
                                             :group_details, :agent_properties_vendor_buying_reqs, :verify_property_through_agent,
                                             :agent_enquiries_buyer_reqs, :branch_mailshot_properties, :search_agent,
                                             :preemption_conversion_rate ]

  around_action :authenticate_agent_and_buyer, only: [ :company_details, :branch_details, :assigned_agent_details ]


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
    page_size = 20
    search_results = klasses.map { |e|  e.constantize.where("lower(name) LIKE ?", "#{params[:str].downcase}%").limit(page_size).as_json }
    results = []
    search_results.each_with_index do |result, index|
      new_row = {}
      new_row[:type] = klass_map[klasses[index]]
      new_row[:result] = result
      results.push(new_row)
    end
    render json: results, status: 200
  end

  ### Companies search
  ### curl -XGET 'http://localhost/agents/search/companies?str=Dyn' 
  def search_company
    page_size = 20
    companies = Agent.where("lower(name) LIKE ?", "#{params[:str].downcase}%").select([:id, :name]).limit(page_size)
    render json: companies, status: 200
  end

  ### Search agent of a particular branch
  ### curl -XGET 'http://localhost/agents/search/assigned_agents?str=Dyn' 
  def search_agent
    agent = @current_user
    page_size = 20
    agents = Agents::Branches::AssignedAgent.where("lower(first_name) LIKE ?", "#{params[:str].downcase}%")
                                            .where(branch_id: agent.branch_id)
                                            .select([:id, :first_name, :last_name, :email])
                                            .limit(page_size)
                                            .map{ |t| { id: t.id, first_name: t.first_name, last_name: t.last_name, email: t.email } }
    render json: agents, status: 200
  end

  ### Branch search
  ### curl -XGET 'http://localhost/agents/search/branches?str=Dyn' 
  def search_branch
    page_size = 20
    branches = Agents::Branch.where("lower(name) LIKE ?", "#{params[:str].downcase}%").select([:id, :name]).limit(page_size)
    render json: branches, status: 200
  end

  def quotes_per_property
    quotes = AgentApi.new(params[:udprn].to_i, params[:agent_id].to_i).calculate_quotes
    render json: quotes, status: 200
  end

  ### Details of the agent
  ### curl -XGET 'http://localhost/agents/agent/1234'
  def assigned_agent_details
    assigned_agent = Agents::Branches::AssignedAgent.find(params[:assigned_agent_id].to_i)
    if @current_user.class.name == 'Vendor' || @current_user.branch.agent.group_id == assigned_agent.branch.agent.group_id
      agent_details = assigned_agent.as_json(methods: [:active_properties, :vanity_url], except: [:password_digest, :password, :provider, :uid, :oauth_token, :oauth_expires_at, :invited_agents])
      agent_details[:company_id] = assigned_agent.branch.agent_id
      agent_details[:group_id] = assigned_agent.branch.agent.group_id
      agent_details[:company_name] = assigned_agent.branch.agent.name
      agent_details[:domain_name] = assigned_agent.branch.domain_name
      render json: agent_details, status: 200
    else
      message = "Sorry, but you do not have permission to view this page"
      render json: { message: message }, status: 400
    end
  end
 
  ### Details of the company
  ### curl XGET 'http://localhost/agents/company/6290'
  def company_details
    company_id = params[:company_id]
    #company_details = cache_response_value(company_id) do 
        company_details = Agent.find(company_id)
        if @current_user.class.name == 'Vendor' || @current_user.branch.agent.group_id == company_details.group_id
          company_details = company_details.as_json(methods: [:vanity_url, :children_vanity_urls], include:  { branches: { include: { assigned_agents: {methods: [:active_properties], except: [ :password_digest, :password, :provider, :uid, :oauth_token, :oauth_expires_at ]}}, except: [:verification_hash]}})
          render json: company_details, status: 200
        else
          message = "Sorry, but you do not have permission to view this page"
          render json: { message: message }, status: 401
        end
    #end
  end

  ### Details of the group
  ### curl XGET 'http://localhost/agents/group/1'
  def group_details
    group_id = params[:group_id]
    #group_details = cache_response_value(group_id) do 
      group = Agents::Group.find(group_id)
      if @current_user.class.name == 'Vendor' || @current_user.branch.agent.group_id == group.id
        group_details = group.as_json(methods: [:vanity_url, :children_vanity_urls], include:  { companies: { include: { branches: { include: { assigned_agents: {methods: [:active_properties]}}}}}})
        render json: group_details, status: 200
      else
        message = "Sorry, but you do not have permission to view this page"
        render json: { message: message }, status: 401
      end
    #end
  end

  ### Details of the branch
  ### curl -XGET 'http://localhost/agents/branch/9851'
  def branch_details
    branch_id = params[:branch_id]
    status = nil
    #branch_details = cache_response_value(branch_id) do
      branch = Agents::Branch.where(id: branch_id).last
      if branch && ( @current_user.class.name == 'Vendor' || @current_user.branch.agent.group_id == branch.agent.group_id )

        branch_details = branch.as_json(methods: [:vanity_url, :children_vanity_urls], include: {assigned_agents: {methods: [:active_properties], except: [:password_digest, 
                                                  :password, :provider, :uid, :oauth_token, :oauth_expires_at, :invited_agents]}},
                                        except: [:verification_hash, :invited_agents])
        branch_details[:company_id] = branch.agent_id
        first_agent_id = Agents::Branches::AssignedAgent.where(branch_id: branch.id).order('id asc').limit(1).pluck(:id).first.to_i
        branch_details['assigned_agents'] = branch_details['assigned_agents'].select{|t| t['id'].to_i != first_agent_id }
        branch_details[:group_id] = branch.agent.group.id
        branch_details[:invited_agents] = InvitedAgent.where(branch_id: branch_id).select([:email, :created_at]).as_json
        branch_details[:invited_agents].each do |invited_agent|
          invited_agent.delete('id')
          invited_agent['branch_id'] = branch_id.to_i 
          invited_agent['group_id'] = branch_details[:group_id].to_i
        end
        branch_details
        status = 200
      else
        branch_details = { message: "Sorry, but you do not have permission to view this page" }
        status = 401
      end
    #end
    status = nil
    render json: branch_details, status: status
  end

  #### Invite the other agents to register
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/agents/invite' -d '{"branch_id" : 9851, "invited_agents" : "\[ \{ \"branch_id\" : 9851, \"company_id\" : 6290, \"email\" : \"test@prophety.co.uk\" \} ]" }'
  def invite_agents_to_register
    agent_id = params[:branch_id].to_i
    branch = Agents::Branch.where(id: agent_id).last
    Rails.logger.info("INVITE_AGENTS_#{branch.id}_#{params[:invited_agents]}")
    agent_id = @current_user.id
    other_agents = JSON.parse(params[:invited_agents])
    invited_email = other_agents.first['email']
    if branch && (Agents::Branches::AssignedAgent.where(email: invited_email).count == 0)
      new_agents = [{email: other_agents.first['email'], entity_id: @current_user.id, branch_id: other_agents.first['branch_id']}]
      branch.invited_agents = new_agents
      branch.send_emails
      render json: { message: 'Branch with given emails invited' }, status: 200
    else
      render json: { message: 'Branch with given branch_id doesnt exist' }, status: 400
    end
  end

  ### An api to edit the agent details
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost/agents/23/edit' -d '{ "agent" : { "name" : "Jackie Bing", "email" : "jackie.bing@friends.com", "mobile" : "9873628232", "password" : "1234567890", "branch_id" : 9851, "office_phone_number" : "9876543210", "mobile_phone_number": "7896543219" } }'
  def edit
    agent_id = params[:id].to_i
    Rails.logger.info("EDIT_AGENTS_#{agent_id.to_i}_#{params[:agent]}")
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
  #rescue 
  #  render json: {message: 'Failed to Updated successfully'}, status: 200
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
    Rails.logger.info("AGENTS_VERIFY_#{udprn}_#{verification_hash}")
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
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/udprns/10968961/agents/23/verify' -d '{"invitation_id":34, "status" : true}'
  def verify_agent
    udprn = params[:udprn].to_i
    agent_id = params[:agent_id].to_i

    if params[:status].to_s == 'true'
      InvitedVendor.where(id: params[:invitation_id].to_i).update_all(accepted: true)
      Rails.logger.info("VERIFY_AGENT_#{udprn}_#{agent_id}_#{params[:property_status_type]}")
      property_status_type = params[:property_status_type]
      update_hash = { verification_status: false, agent_id: agent_id, agent_status: 2 }
      update_hash[:property_status_type] = property_status_type if property_status_type
      response, status = PropertyService.new(udprn).update_details(update_hash)
      response['message'] = "Agent verification successful." unless status.nil? || status!=200
      render json: response, status: status
    else
      InvitedVendor.where(id: params[:invitation_id].to_i).update_all(accepted: false)
      render json: { message: 'Agent invitation has been rejected for this property' }, status: 200
    end

  end

  ### Verify the property as the intended agent and udprn as the correct udprn.
  ### Done when the invited vendor(through email) verifies the property as his/her
  ### property and the agent as his/her agent.
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/udprns/10968961/verify' -d '{ "verified": true, "vendor_id":319, "invitation_id":34, "agent_id" : 231, "status": true }'
  def verify_property_from_vendor
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    response, status = nil
    udprn = params[:udprn].to_i
    property_status_type = params[:property_status_type] if params[:property_status_type]
    details = {}
    details[:property_status_type] = property_status_type if params[:property_status_type]
    details[:beds] = params[:beds].to_i if params[:beds]
    details[:baths] = params[:baths].to_i if params[:baths]
    details[:receptions] = params[:receptions].to_i if params[:receptions]
    details[:property_type] = params[:property_type] if params[:property_type]
    details[:dream_price] = params[:dream_price].to_i if params[:dream_price]
    details[:claimed_on] = Time.now.to_s
    details[:vendor_id] = params[:vendor_id].to_i if params[:vendor_id]
    details[:verification_status] = false
    vendor_id = details[:vendor_id].to_i

    Rails.logger.info("VERIFY_VENDOR_#{udprn}_#{vendor_id}_#{params[:beds].to_i}_#{params[:baths].to_i}")

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
    agent = @current_user
    udprn = params[:udprn].to_i
    agent_id = params[:agent_id].to_i
    agent_service = AgentService.new(agent_id, udprn)
    property_for = params[:property_for]
    property_for ||= 'Sale'
    property_status_type = nil
    Rails.logger.info("UPLOAD_CRAWLED_PROPERTY_#{udprn}_#{agent_id}")
    pictures = params[:pictures]
    property_attrs = {
      property_status_type: 'Green',
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
    response, status = agent_service.verify_crawled_property_from_agent(property_attrs, vendor_email, assigned_agent_email, agent)
    response['message'] = 'Property details updated.' unless status.nil? || status != 200
    render json: response, status: status
#  rescue Exception => e
#    Rails.logger.info("AGENT_PROPERTY_VERIFICATION_FAILURE_#{e.message}")
#    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Add manual property's basic attributes and attach the crawled property to a udprn for a non f and f property
  ### Done when the agent attaches the udprn to the property
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/agents/properties/10968961/manual/verify/non/fandf' -d '{  "agent_id": 1234, "vendor_email": "residentevil293@prophety.co.uk", "assigned_agent_email" :  "residentevil293@prophety.co.uk", "assigned_agent_id" : 1234 }'
  def verify_manual_property_from_agent_non_f_and_f
    agent = @current_user
    udprn = params[:udprn].to_i
    agent_id = params[:assigned_agent_id].to_i
    assigned_agent = agent.class.where(id: agent_id).last
    vendor_email = params[:vendor_email]

    if (Vendor.where(email: vendor_email).count == 0)
      agent_service = AgentService.new(agent_id, udprn)
      Rails.logger.info("UPLOAD_MANUAL_PROPERTY_NON_F&F_#{udprn}_#{agent_id}")
      property_attrs = {
        details_completed: false,
        claimed_on: Time.now.to_s,
        claimed_by: 'Agent',
        agent_id: agent_id,
        property_id: params[:udprn],
        property_status_type: 'Green'
      }
      Rails.logger.info("#{property_attrs}  CLAIM_PROPERTY_#{agent.id}")
      
      assigned_agent_email = params[:assigned_agent_email]
      response, status = agent_service.verify_manual_property_from_agent_non_f_and_f(property_attrs, vendor_email, assigned_agent_email, assigned_agent)
      response['message'] = "Property details updated." unless status.nil? || status != 200
      render json: response, status: status
    else
      render json: { message: 'The user is already registered.' }, status: 400
    end
  #rescue Exception => e
  #  Rails.logger.info("AGENT_MANUAL_PROPERTY_VERIFICATION_FAILURE_#{e}")
  #  render json: { message: 'Verification failed due to some error' }, status: 400
  end

  ### Add manual property's basic attributes and attach the crawled property to a udprn
  ### Done when the agent attaches the udprn to the property
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/agents/properties/10968961/manual/verify' -d '{ "property_type" : "Barn conversion", "beds" : 1, "baths" : 1, "receptions" : 1, "agent_id": 1234, "vendor_email": "residentevil293@prophety.co.uk", "assigned_agent_email" :  "residentevil293@prophety.co.uk" }'
  def verify_manual_property_from_agent
    agent = @current_user
    udprn = params[:udprn].to_i
    agent_id = agent.id
    agent_service = AgentService.new(agent_id, udprn)
    Rails.logger.info("UPLOAD_MANUAL_PROPERTY_#{udprn}_#{agent_id}")
    property_attrs = {
      verification_status: false,
      property_type: params[:property_type],
      receptions: params[:receptions].to_i,
      beds: params[:beds].to_i,
      baths: params[:baths].to_i,
      details_completed: false,
      property_id: udprn,
      claimed_on: Time.now.to_s,
      claimed_by: 'Agent',
      agent_id: agent_id.to_i,
      property_status_type: 'Red'
    }
    Rails.logger.info("#{property_attrs}  CLAIM_PROPERTY_#{agent.id}")
    
    vendor_email = params[:vendor_email]
    assigned_agent_email = params[:assigned_agent_email]
    response, status = agent_service.verify_manual_property_from_agent(property_attrs, vendor_email, assigned_agent_email, agent)
    response['message'] = "Property details updated." unless status.nil? || status != 200
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
    page_size = 5
    Rails.logger.info("GET_CRAWLED_PROPERTY_#{agent_id}")
    if agent
      branch_id = agent.branch_id
      properties = Agents::Branches::CrawledProperty.where(branch_id: branch_id).select([:id, :postcode, :image_urls, :stored_response, :additional_details, :udprn]).where.not(postcode: nil).where(udprn: nil).limit(page_size).offset(page_no*page_size).order('created_at asc')
      property_count = Agents::Branches::CrawledProperty.where(branch_id: branch_id).where.not(postcode: nil).where(udprn: nil).count
      assigned_agent_emails = Agents::Branches::AssignedAgent.where(branch_id: branch_id).pluck(:email)
      properties.each do |property|
        new_row = {}
        new_row['property_id'] = property.id
        new_row['address'] = property.stored_response['address']
        new_row['image_urls'] = property.image_urls.map { |e| base_url + e }
        new_row['post_code'] = property.postcode
        new_row['property_status_type'] = 'Green'
        new_row['assigned_agent_emails'] = assigned_agent_emails
        new_row['udprn'] = property.udprn
        postcode = property.postcode
        response.push(new_row)
        postcodes = postcodes + "," + postcode
      end
      #query = PropertyAddress
      #where_query = postcodes.split(',').map{ |t| t.split(' ').join('') }.map{ |t| "(to_tsvector('simple'::regconfig, postcode)  @@ to_tsquery('simple', '#{t}'))" }.join(' OR ')
      #results = PropertyAddress.connection.execute(query.where(where_query).select([:udprn, :postcode]).limit(1000).to_sql).to_a
      #results = []
      #Rails.logger.info(results.as_json)
      response.each do |each_crawled_property_data|
        if !each_crawled_property_data['udprn'] 
          each_crawled_property_data['last_email_sent'] = nil
          each_crawled_property_data['vendor_email'] = nil
          each_crawled_property_data['is_vendor_registered'] = false
        end
        each_crawled_property_data['udprn'] = each_crawled_property_data['udprn'].to_f
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
    Rails.logger.info("EDIT_BRANCH_DETAILS_#{branch.id}")
    if branch
      branch_details = params[:branch]
      branch.name = branch_details[:name] if branch_details[:name] && !branch_details[:name].blank?
      branch.address = branch_details[:address] if branch_details[:address] && !branch_details[:address].blank?
      branch.phone_number = branch_details[:phone_number] if branch_details[:phone_number] && !branch_details[:phone_number].blank?
      branch.website = branch_details[:website] if branch_details[:website] && !branch_details[:website].blank?
      branch.image_url = branch_details[:image_url] if branch_details[:image_url] && !branch_details[:image_url].blank?
      branch.email = branch_details[:email] if branch_details[:email] && !branch_details[:email].blank?
      branch.domain_name = branch_details[:domain_name] if branch_details[:domain_name] && !branch_details[:domain_name].blank?
      agents = branch.assigned_agents
      agents.each { |agent| AgentUpdateWorker.perform_async(agent.id) }

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
    Rails.logger.info("EDIT_COMPANY_DETAILS_#{company.id}")
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
      Rails.logger.info("EDIT_GROUP_DETAILS_#{group.id}")
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
      Rails.logger.info("ADD_CREDITS_#{agent.id}")
      begin
        customer = Stripe::Customer.create(
          email: params[:stripeEmail],
          card: params[:stripeToken]
        )
        amount = ((Agents::Branches::AssignedAgent::PER_CREDIT_COST*params[:credit].to_i).round)*100 ### In pences
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
        Rails.logger.info("REFUND_INITIATED_#{e.message}_#{agent}_#{params[:credit]}")
        render json: { message: 'Unsuccessful in adding credits' }, status: 401
      end
    end
  
    ### Unlock locked agents by paying one time Stripe payment
    ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/unlock/agents' -d '{ "stripeEmail" : "abhiuec@gmail.com", "stripeToken":"tok_19WlE9AKL3KAwfPBkWwgTpqt", "amount" : 100}'
    def unlock_agent
      agent = @current_user
      Rails.logger.info("UNLOCK_AGENTS_STARTED_#{agent.id}")
      begin
        customer = Stripe::Customer.create(
          email: params[:stripeEmail],
          card: params[:stripeToken]
        )
  
      if params[:amount].to_i == Agents::Branches::AssignedAgent::ONE_TIME_UNLOCKING_COST
        amount = Agents::Branches::AssignedAgent::ONE_TIME_UNLOCKING_COST*100 ### In pences
  
        charge = Stripe::Charge.create(
          customer: customer.id,
          amount: amount,
          description: 'Add credit to agents Stripe customer',
          currency: 'GBP'
        )
        agent.locked = false
        agent.save!

        Rails.logger.info("AGENT_UNLOCKED_#{agent.id}")
        Stripe::Payment.create!(entity_type: 'Agents::Branches::AssignedAgent', entity_id: agent.id, amount: amount, charge_id: charge.id, udprn: params[:udprn].to_i)
        render json: { message: 'Successfully unlocked the agent' }, status: 200
      else
        render json: { message: 'Amount is incorrect' }, status: 400
      end
    rescue Exception => e
      Rails.logger.info("REFUND_INITIATED_#{e.message}_#{agent}___#{params[:credit]}")
      render json: { message: 'Unsuccessful in adding credits' }, status: 401
    end
  end


  ### Gets the info about the credits remaining and the credits locked for the quotes
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9" -H "Content-Type: application/json" 'http://localhost/agents/credit/info/'
  def agent_credit_info
    agent = @current_user
    remaining_credits = agent.credit
    klass = Agents::Branches::AssignedAgents::Quote
    new_status = klass::STATUS_HASH['New']
    new_quotes = klass.where(agent_id: @current_user.id).where(status: new_status).where(expired: false).pluck(:amount)
    quote_count = new_quotes.count
    locked_amount = new_quotes.reduce(:+)
    locked_credits = (locked_amount.to_f*0.01*0.01).round/Agents::Branches::AssignedAgent::PER_CREDIT_COST
    result_hash = { total_credits: (locked_credits + remaining_credits), remaining_credits: remaining_credits,
                    locked_credits: locked_credits, quote_count: quote_count }
    render json: result_hash, status: 200
  end

  ### Invited agents history for branches
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/agents/list/invited/agents'
  def branch_specific_invited_agents
    agent = @current_user
    branch_id = agent.branch_id
    invited_agents = InvitedAgent.where(branch_id: branch_id).select([:email, :created_at, :branch_id])
    agent_emails = invited_agents.map(&:email).uniq
    agents_invited = Agents::Branches::AssignedAgent.where(email: agent_emails).pluck(:email)

    invited_agents.each do |invited_agent|
      invited_agent.is_registered = agents_invited.include?(invited_agent.email)
    end

    render json: invited_agents ,methods: [:is_registered], status: 200
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
    Rails.logger.info("SUBSCRIBE_PREMIUM_SERVICE_#{agent.id}")
    begin
      # Create the customer in Stripe
      customer = Stripe::Customer.create(
        email: params[:stripeEmail],
        card: params[:stripeToken],
        description: 'Agent subscription for premium service'
      )
      stripe_subscription = customer.subscriptions.create(:plan => 'agent_monthly_premium_package')
      agent.is_premium = true
      agent.stripe_customer_id = customer.id
      agent.premium_expires_at = 1.month.from_now.to_date
      agent.save!

      ### Notify a vendor that a vendor has upgraded to premium
      AgentUpgradePremiumNotifyAgentWorker.perform_async(agent.id)

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
        user = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(stripe_customer_id: event.data.object.customer).last
        user ||= PropertyBuyer.where(stripe_customer_id: event.data.object.customer).last
        if user
          user.premium_expires_at = 1.month.from_now.to_date
          user.save!
        end
    end
    render status: :ok, json: 'success'
  end

  ### Stripe agents subscription recurring payment
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/premium/subscription/remove'
  def remove_subscription
    agent = @current_user
    Rails.logger.info("REMOVE_SUBSCRIBE_PREMIUM_SERVICE_#{agent.id}")
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
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/branches/list/:location'
  def branch_info_for_location
    vendor = user_valid_for_viewing?('Vendor', ['Vendor', 'Agent'])
    #vendor = user_valid_for_viewing?('Agent')
    ### Either a vendor or a premium developer
    if !vendor.nil? && (vendor.class.to_s == 'Vendor' || (vendor.class.to_s == 'Agents::Branches::AssignedAgent' && vendor.is_developer ))
    #if true
      count = Agents::Branch.unscope(where: :is_developer).where(district: params[:location]).count
      #results = Agents::Branch.unscope(where: :is_developer).where(district: params[:location]).limit(20).offset(20*(params[:p].to_i)).map do |branch|
      results = Agents::Branch.unscope(where: :is_developer).where(district: params[:location]).order('name ASC').map do |branch|
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
          agent_count: agent_count,
          branch_stats: branch.branch_specific_stats
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
    InvitedVendor.where(agent_id: agent.id).where(source: [ Vendor::INVITED_FROM_CONST[:family], Vendor::INVITED_FROM_CONST[:non_crawled] ]).group(:email, :id).order('created_at DESC').each do |invited_vendor|
      udprn = invited_vendor.udprn
      details = PropertyDetails.details(udprn)[:_source]
      result = {
        beds: details[:beds],
        baths: details[:baths],
        receptions: details[:receptions],
        vendor_email: invited_vendor.email,
        property_type: details[:property_type],
        address: details[:address],
        udprn: details[:udprn],
        source: Vendor::REVERSE_INVITED_FROM_CONST[invited_vendor.source.to_i].to_s,
        last_email_sent: invited_vendor.created_at,
        is_vendor_registered: !Vendor.where(email: invited_vendor.email).last.nil?
      }
      results.push(result)
    end
    render json: results, status: 200
  end

  ### Preemption stats for properties
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/premeption/conversion/rate'
  def preemption_conversion_rate
    agent = @current_user
    total_preempted_stats = AddressDistrictRegister.where(agent_id: agent.id).count
    vendor_registered_stats = AddressDistrictRegister.where(agent_id: agent.id, vendor_registered: true).count
    render json: { total_properties_invited: total_preempted_stats, vendor_registered_stats: vendor_registered_stats }, status: 200
  end

  ### List of properties which have been won by the agent, to be show for filling sale price
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/properties/quotes/missing/price'
  def missing_sale_price_properties_for_agents
    agent = @current_user
    Rails.logger.info("MISSING_SALE_PRICE__#{agent.id}")
    response = cache_response_value(agent.id) do
      agent = @current_user
      api = PropertySearchApi.new(filtered_params: { not_exists: 'sale_price', agent_id: agent.id, results_per_page: 200 })
      api = api.filter_query
      result, status = api.filter
      { result: result, status: status }
    end

    response = response.with_indifferent_access
    if response[:status].to_i == 200
      render json: response[:result], status: response[:status]
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
    offer_price = Event.where(buyer_id: buyer_id, udprn: udprn).order('created_at DESC').select([:offer_price]).first.offer_price
    credits = ((Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(offer_price.to_f)).round/Agents::Branches::AssignedAgent::PER_CREDIT_COST)
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
    Rails.logger.info("CLAIM_LEAD_AGENT_#{agent.id}_#{agent.credit}_#{agent.email}_#{registered_vendor_count}")
    if registered_vendor_count >= Agents::Branches::AssignedAgent::MIN_INVITED_FRIENDS_FAMILY_VALUE
      if agent.credit >= Agents::Branches::AssignedAgent::LEAD_CREDIT_LIMIT
      #if true
        property_service = PropertyService.new(params[:udprn].to_i)
        message, status = property_service.claim_new_property(params[:agent_id].to_i)
        render json: { message: message, deadline: message[:deadline] }, status: status
      else
        render json: { message: "Credits possessed for leads #{agent.credit}, not more than #{Agents::Branches::AssignedAgent::LEAD_CREDIT_LIMIT} " }, status: 401
      end
    else
      if invited_vendor_emails.count == 0
        render json: { message: "No friends and family invited yet" }, status: 400
      else
        render json: { message: "Registered friends family count #{registered_vendor_count} is below than minimum value of #{Agents::Branches::AssignedAgent::MIN_INVITED_FRIENDS_FAMILY_VALUE}" }, status: 400
      end
    end
  end

  #### On demand quicklink for all the properties of agents, or group or branch or company
  #### To get list of properties for the concerned agent
  #### curl -XGET 'http://localhost/agents/properties?agent_id=1234'
  #### Filters on property_for, ads
  def detailed_properties
    cache_parameters = [ :agent_id, :property_status_type, :verification_status, :ads ].map{ |t| params[t].to_s }
    #cache_response_and_value(params[:agent_id].to_i, []) do
      response = {}
      results = []
      count = params[:count].to_s == 'true'
      old_stats_flag = params[:old_stats_flag].to_s == 'true'

      unless params[:agent_id].nil?
        #### TODO: Need to fix agents quotes when verified by the vendor
        agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: params[:agent_id].to_i).select([:id, :is_premium]).first
        if agent
          old_stats_flag = params[:old_stats_flag].to_s == 'true'
          search_params = {}
          search_params[:agent_id] = params[:agent_id].to_i
          search_params[:p] = params[:page].to_i
          search_params[:p] = 1 if search_params[:p] == 0 
          agent.is_premium ? search_params[:results_per_page] = 200 : search_params[:results_per_page] = 5
          property_status_type = params[:property_status_type]

          search_params[:property_status_type] = params[:property_status_type] if params[:property_status_type]
          search_params[:verification_status] = true if params[:verification_status] == 'true'
          search_params[:verification_status] = false if params[:verification_status] == 'false'
          search_params[:sort_key] = 'status_last_updated'
          search_params[:sort_order] = 'desc'

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
          #api.query[:size] = 10000

          ### Take the first exists status updated at filter out
          api.query[:filter][:and][:filters] = [ api.query[:filter][:and][:filters].last ]

          udprns, status = api.fetch_udprns
          Rails.logger.info("AGENT_PROPERTIES_QUERY_#{api.query}")
          total_count = api.total_count

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
            udprns = property_ids.uniq.map(&:to_i)
            bulk_details = PropertyService.bulk_details(udprns)
            bulk_details.each {|t| t[:address] = PropertyDetails.address(t) }
            results = property_ids.uniq.each_with_index.map { |e, index| Enquiries::AgentService.push_events_details( { '_source' => bulk_details[index] }.with_indifferent_access, agent.is_premium, old_stats_flag) }
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

          response = (!results.is_a?(Fixnum) && results.empty?) ? { "properties" => results, "message" => "No properties to show", 'count' => total_count } : { "properties" => results, 'count' => total_count }
        else
          render json: { message: 'Agent id not found in the db'}, status: 400
        end
        #Rails.logger.info "Sending results for detailed properties (agent) => #{results.inspect}"
      else
        response = { message: 'Agent ID mandatory for getting properties' }
      end
      @current_response = response
      #Rails.logger.info "Sending response for detailed properties (agent) => #{response.inspect}"
    #end

#    if @current_response['properties'] && @current_response['properties'].is_a?(Array)
#      udprns = @current_response['properties'].map{|t| t['udprn'].to_i }
#      bulk_details = PropertyService.bulk_details(udprns)
#      bulk_details.each_with_index do |detail_hash, index|
#        property_hash = { '_source' => detail_hash }
#        property_hash = property_hash.with_indifferent_access
#        Enquiries::AgentService.merge_property_details(property_hash, @current_response['properties'][index])
#      end
#    end
#
    render json: @current_response, status: 200
  end
  
  ### Provides a list of udprns for the matching property
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9" 'http://localhost/agents/matching/udprns/property/:property_id'
  def matching_udprns
    property_id = params[:property_id]
    property = Agents::Branches::CrawledProperty.where(id: property_id).last
    if property
      postcode = property.postcode
      results, code = PropertyService.get_results_from_es_suggest(postcode.upcase, 1)
      predictions = Oj.load(results)['postcode_suggest'][0]['options']

      if predictions.length > 0
        type = predictions.first['text'].split('|')[0]
        if type == 'unit'
          udprn = predictions.first['text'].split('|')[1]
          details = PropertyDetails.details(udprn)[:_source]
          hash_str = MatrixViewService.form_hash(details, :unit)
          search_params = { hash_str: hash_str, hash_type: 'unit', results_per_page: 1000 }
          api = PropertySearchApi.new(filtered_params: search_params)
          results, code = api.filter
          results = results[:results]
          render json: results, status: code.to_i
        else
          render json: [], status: 200
        end
      else
        render json: [], status: 200
      end
    else
      render json: [], status: 200
    end
  end
  
  ### Get the list of properties the agent has been attached to
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOi" 'http://localhost/agents/list/incomplete/properties'
  def incomplete_list_of_properties
    #@current_user = Agents::Branches::AssignedAgent.find(232)
    search_params = { agent_id: @current_user.id, results_per_page: 200 }
    #search_params = { agent_id: 113, results_per_page: 200 }
    api = PropertySearchApi.new(filtered_params: search_params)
    api.modify_filtered_params
    api.apply_filters
    udprns, status = api.fetch_udprns
    total_count = api.total_count
    bulk_results = PropertyService.bulk_details(udprns)

    leads = Agents::Branches::AssignedAgents::Lead.where(agent_id: @current_user.id, property_id: udprns, expired: false).select([:created_at, :property_id, :owned_property])

    results = bulk_results.map do |result|
      result[:address] = PropertyDetails.address(result)
      result[:percent_completed] = PropertyService.new(result[:udprn]).compute_percent_completed({}, result)
      result = result.slice(:beds, :baths, :property_type, :property_status_type, :receptions, :address, :udprn, :percent_completed, :claimed_on)
      lead = leads.select{|t| t.property_id == result[:udprn].to_i }.first
      result[:expiry_time] = (lead.created_at + Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT).strftime("%Y-%m-%dT%H:%M:%SZ") if lead
      result
    end

    results = results.select{ |t| t[:percent_completed].to_f < 100 }.sort_by{ |t| t[:percent_completed].to_i }

    render json: results, status: 200
  end

  ### Get the list of properties the agent has been attached to
  ### curl -XGET 'http://localhost/agents/list/properties?incomplete_details=true'
  def list_of_properties
    #@current_user = Agents::Branches::AssignedAgent.find(232)
    search_params = { agent_id: @current_user.id, results_per_page: 200 }
    #search_params = { agent_id: 113, results_per_page: 200 }
    api = PropertySearchApi.new(filtered_params: search_params)
    api.modify_filtered_params
    api.apply_filters
    udprns, status = api.fetch_udprns
    total_count = api.total_count
    bulk_results = PropertyService.bulk_details(udprns)
    results = bulk_results.map do |result|
      result[:address] = PropertyDetails.address(result)
      result[:percent_completed] = PropertyService.new(result[:udprn]).compute_percent_completed({}, result)
      result = result.slice(:beds, :baths, :property_type, :property_status_type, :receptions, :address, :udprn, :percent_completed, :claimed_on)
      result
    end

    if params[:incomplete_details].to_s == 'true'
      udprns = results.map{ |t| t[:udprn] }
      leads = Agents::Branches::AssignedAgents::Lead.where(agent_id: @current_user.id, property_id: udprns, expired: false).select([:created_at, :property_id, :owned_property])
      leads.each_with_index do |lead|
        index =  results.index{ |t| t[:udprn].to_i == lead.property_id }
        #Rails.logger.info("#{index} #{results[index]} hello")
        results[index][:lead_expiry_time] = nil
        results[index][:lead_expiry_time] = lead.claimed_at + Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT if !lead.owned_property && lead.claimed_at
      end
      udprns = leads.map{ |t| t.property_id }
      results = results.select{ |t| t[:percent_completed].to_f < 100 }
    elsif  params[:incomplete_details].to_s == 'false'
      results = results.select{ |t| t[:percent_completed].to_f == 100 }
    end
    #Rails.logger.info("RESULTS #{results}")

    render json: results, status: 200
  end

  ### Used to fetch agent details when queried for a vanity url
  ### curl -XGET -H "Authorization: abxsbsk21w1xa" 'http://localhost/agents/details/:vanity_url'
  def agent_vanity_url_details
    vanity_url = params[:vanity_url]
    agent_id = vanity_url.split('-').last
    agent_id = agent_id.to_i
    agent = Agents::Branches::AssigndAgent.where(id: agent_id).last
    if agent
      render json: agent.details, status: 200
    else
      render json: { message: 'Agent not present in the db' }, status: 400
    end
  end

  ### Used to fetch branch details when queried for a vanity url
  ### curl -XGET -H "Authorization: abxsbsk21w1xa" 'http://localhost/branches/details/:vanity_url'
  def branch_vanity_url_details
    vanity_url = params[:vanity_url]
    branch_id = vanity_url.split('-').last
    branch_id = branch_id.to_i
    branch = Agents::Branch.where(id: branch_id).last
    if branch
      children_vanity_urls = branch.assigned_agents.map(&:vanity_url)
      branch = branch.as_json
      branch['children_vanity_urls'] = children_vanity_urls
      render json: branch, status: 200
    else
      render json: { message: 'Branch not present in the db' }, status: 400
    end
  end

  ### Used to fetch company details when queried for a vanity url
  ### curl -XGET -H "Authorization: abxsbsk21w1xa" 'http://localhost/companies/details/:vanity_url'
  def company_vanity_url_details
    vanity_url = params[:vanity_url]
    company_id = vanity_url.split('-').last
    company_id = company_id.to_i
    company = Agent.where(id: company_id).last
    if company
      children_vanity_urls = company.branches.map(&:vanity_url)
      company = company.as_json
      company['children_vanity_urls'] = children_vanity_urls
      render json: company, status: 200
    else
      render json: { message: 'Company not present in the db' }, status: 400
    end
  end

  ### Used to fetch company details when queried for a vanity url
  ### curl -XGET -H "Authorization: abxsbsk21w1xa" 'http://localhost/groups/details/:vanity_url'
  def group_vanity_url_details
    vanity_url = params[:vanity_url]
    group_id = vanity_url.split('-').last
    group_id = group_id.to_i
    group = Agents::Group.where(id: group_id).last
    if group
      children_vanity_urls = group.companies.map(&:vanity_url)
      group = group.as_json
      group['children_vanity_urls'] = children_vanity_urls
      render json: group, status: 200
    else
      render json: { message: 'Company not present in the db' }, status: 400
    end
  end

  ### Is used to fetch additional details of an agent (registered friends and family and registered agents)
  ### curl -XGET -H "Authorization: abxsbsk21w1xa" 'http://localhost/agents/additional/details'
  def additional_agent_details_intercom
    details = {}
    search_params = { agent_id: @current_user.id } 
    api = PropertySearchApi.new(filtered_params: search_params)
    api.modify_filtered_params
    api.apply_filters

    ### THIS LIMIT IS THE MAXIMUM. CAN BE BREACHED IN AN EXCEPTIONAL CASE
    #api.query[:size] = 10000
    udprns, status = api.fetch_udprns
    details[:branch_name] = @current_user.branch.name
    total_count = api.total_count
    details[:properties_count] = total_count
    is_first_agent = (@current_user.class.where(branch_id: @current_user.branch_id).select(:id).order('agents_branches_assigned_agents.id asc').limit(1).first.id == @current_user.id)
    details[:is_first_agent] = is_first_agent
    invited_emails = InvitedAgent.where(entity_id: @current_user.id).pluck(:email)
    details[:invited_agents_count]= Agents::Branches::AssignedAgent.where(email: invited_emails).count
    invited_friends_family_emails = InvitedVendor.where(agent_id: @current_user.id).where(source: Vendor::INVITED_FROM_CONST[:family]).pluck(:email)
    details[:friends_family_count] = Vendor.where(email: invited_friends_family_emails).count
    render json: details, status: 200
  end

  ### Send emails to all buyer emails
  ### curl -XPOST 'http://localhost/agents/properties/send/emails/enquiries' -d '{ "udprn" : 8097861, "segment" : "include_archived", "body" : "sxbksavckwcvkwv", "subject" : "Random subject" }'
  def send_emails_to_enquiry_producing_buyers
    agent = @current_user
    udprn = params[:udprn].to_i
    subject = params[:subject]
    body = params[:body]
    buyer_emails = []

    event_model = Event
    event_model = event_model.unscope(where: :is_archived) if params[:segment] == 'include_archived' && agent.is_premium
    buyer_ids = event_model.where(udprn: udprn).pluck(:buyer_id).uniq
    buyer_emails = PropertyBuyer.where(id: buyer_ids).pluck(:email)

    ### Send emails to all buyer emails
    required_credit = agent.class::PER_BUYER_ENQUIRY_EMAIL_COST*buyer_emails.count
    if agent.credit >= required_credit
      agent.credit -= required_credit
      agent.save!
      SesSendBulkEmailWorker.perform_async(buyer_emails, agent.email, body, subject) if !buyer_emails.empty?
      render json: { message: 'Bulk emails sent to all the buyers', enquiry_count: buyer_emails.count }, status: 200
    else
      render json: { required_credit: required_credit, credits_remaining: agent.credit, message: 'Credits remaining are not enough to send enquiries' }, status: 200
    end
  end

  ### Send bulk emails to buyers from agents
  ### curl -XPOST 'http://localhost/agents/bulk/send/buyers/emails' -d '{ "subject" : "Random subject", "body": "Gusnz adkasc ak", "buyer_emails" : [ "a@b.com", "b@c.com", "c@d.com" ]  }'
  def send_bulk_emails_to_buyers
    agent = @current_user
    subject = params[:subject]
    body = params[:body]
    buyer_emails = params[:buyer_emails]
    SesSendBulkEmailWorker.perform_async(buyer_emails, agent.email, body, subject) if !buyer_emails.empty?
    render json: { message: 'Bulk emails queued for sending' }, status: 200
  end

  ### Send emails to all buyer emails
  ### curl -XGET -H "Authorization: abxsbsk21w1xa" 'http://localhost/agents/enquiry/count/emails/:udprn'
  def enquiry_count_for_buyer_emails
    agent = @current_user
    udprn = params[:udprn].to_i
    event_model = Event
    event_model = event_model.unscope(where: :is_archived) if params[:segment] == 'include_archived' && agent.is_premium
    buyer_ids = event_model.where(udprn: udprn).pluck(:buyer_id).uniq
    buyer_count = PropertyBuyer.where(id: buyer_ids).count
    render json: buyer_count, status: 200
  end

  ### Shows availability of the agent
  ### curl -XGET -H "Authorization: abxsbsk21w1xa" 'http://localhost/agents/availability'
  def show_agent_availability
    agent = @current_user
    meetings = VendorAgentMeetingCalendar.where(agent_id: agent.id).where("created_at > ?", Time.now).select([:id, :agent_id, :vendor_id, :start_time, :end_time])
    unavailable_times = VendorCalendarUnavailability.where(agent_id: agent.id).where("created_at > ?", Time.now)
    render json: { meetings: meetings, unavailable_times: unavailable_times }, status: 200
  end

  ### Add unavailablity slot for the vendor
  ### curl -XPUT -H "Authorization: abxsbsk21w1xa" 'http://localhost/agents/availability' -d '{ "start_time" : "2017-01-10 14:00:06 +00:00", "end_time" : "2017-02-11 15:00:07 +00:00" }'
  def add_unavailable_slot
    agent = @current_user
    start_time = Time.parse(start_time)
    end_time = Time.parse(end_time)
    meeting_details = nil
    if start_time > Time.now && end_time > Time.now && start_time > end_time
      meeting_details = AgentCalendarUnavailability.create!(start_time: start_time, end_time: end_time)
    end
    render json: { meeting_details: meeting_details }, status: 200
  end

  ### Send mailshots to the selected properties
  ### curl -XPOST -H "Authorization: abxsbsk21w1xa" 'http://localhost/agents/properties/send/mailshots' -d '{ "udprns" : [ 671717, 541517, 7626251 ], "district" : "SW5", "months" : 1 }'
  def send_mailshots_to_properties
    agent = @current_user
    branch = agent.branch
    udprns = params[:udprns]
    udprns = [] if !udprns.is_a?(Array)
    mode = 'diy'
    total_collectible_charge = Agents::Branch::CHARGE_PER_PROPERTY_MAP[mode] * udprns.count
    if agent.credit > total_collectible_charge && total_collectible_charge >= Agents::Branch::MIN_MAILSHOT_CHARGE

      branch_mailshot_property_count = AddressDistrictRegister.where(branch_id: branch.id).count
      addresses_count = udprns.count

      if branch_mailshot_property_count + addresses_count <= Agents::Branch::MAX_BRANCH_MAILSHOT_LIMIT

        branch = agent.branch
        payment_group_id = AddressDistrictRegister.pluck("max(id)").first.to_i
        payment_group_id ||= 1
        bulk_details = PropertyService.bulk_details(udprns)
  
        bulk_details.each do |detail|
          udprn = detail[:udprn]
  
          ### Prevent an already registered property from being registered
          if (detail[:agent_id].to_i == 0) && (detail[:vendor_id].to_i == 0)
            AddressDistrictRegister.create!(
              udprn: udprn, 
              branch_id: branch.id,
              agent_id: agent.id,
              expiry_date: 179.days.from_now.to_date.to_s,
              invite_sent: true,
              payment_group_id: payment_group_id
            )
          end
  
        end
        agent.credit -= total_collectible_charge
        agent.save!
        render json: { message: "Successfully invited all the properties" }, status: 200

      else
        message = { property_limit: Agents::Branch::MAX_BRANCH_MAILSHOT_LIMIT, properties_claimed: branch_mailshot_property_count, properties_attempted: addresses_count }
        render json: message, status: 400
      end

    elsif total_collectible_charge < Agents::Branch::MIN_MAILSHOT_CHARGE
      render json: { message: "Min charge should be greater than atleast #{Agents::Branch::MIN_MAILSHOT_CHARGE}", min_order_size: Agents::Branch::MIN_MAILSHOT_CHARGE }
    else 
      message = "Required credits #{total_collectible_charge} less than credits possessed #{agent.credit}"
      render json: { message: message, credits_required: total_collectible_charge, credits_possessed: agent.credit }
    end
  end

  ### Get list of invited properties for a district
  ### curl -XGET  -H "Content-Type: application/json" -H "Authorization: zxbcskbskbd"  'http://localhost/list/invited/properties/vendors?hash_str=Devon_Plymouth_@_Kilmar%20Street_@_@_@_@_@|PL9%207FJ_PL9%207_PL9&hash_type=text' -d '{"email" : "stephenkassi@gmail.com", "password" : "1234567890", "branch_id" : 22341}'
  def fetch_invited_properties_for_district
    #if AdminAuth.authenticate(params[:email], params[:password])
    #if true
      agent = @current_user
      results = nil
      branch_id = params[:branch_id]
      branch = Agents::Branch.where(id: branch_id).last
      if branch
        district = branch.district
        area = district.match(/[A-Z+]+/)[0]
        mvc = MatrixViewService.new(hash_str: params[:hash_str])
        searched_district = mvc.context_hash[mvc.level].split(' ')[0]
        searched_area = searched_district.match(/[A-Z+]+/)[0] if searched_district
    
        ### Check if the searched area is equal to the area of the branch
        if searched_area.to_s == area.to_s
          property_search_api = PropertySearchApi.new(filtered_params: params)
          udprns, status = property_search_api.matching_udprns
          preassigned_count = AddressDistrictRegister.where(branch_id: branch_id, expired: false).count
          query = AddressDistrictRegister
          query = query.where.not(agent: agent.id) if params[:hide_self_properties].to_s == 'true'
          invitation_udprns = query.where(udprn: udprns, expired: false).select([:vendor_registered, :invite_sent, :udprn, :branch_id, :expiry_date, :processed, :vendor_claimed_at])
          bulk_details = PropertyService.bulk_details(udprns)
    
          results = bulk_details.map do |each_detail|
            invitation_udprn = invitation_udprns.select{|t| t.udprn == each_detail[:udprn].to_i}.last
            is_vendor_registered = branch_assigned = invite_sent = branch_owned = false
            branch_id = vendor_claimed_at = expiry_date = nil
            property_claimed = false
            if invitation_udprn
              invite_sent = true if invitation_udprn.processed.to_s == 'true'
              expiry_date = invitation_udprn.expiry_date
              if invitation_udprn.branch_id != branch.id
                branch_assigned = true
              else
                branch_owned = true
              end
              vendor_claimed_at = invitation_udprn.vendor_claimed_at
              is_vendor_registered = invitation_udprn.vendor_registered
            elsif (each_detail[:vendor_id].to_i > 0) || (each_detail[:agent_id].to_i > 0)
              invite_sent = false
              is_vendor_registered = true if each_detail[:vendor_id].to_i > 0
              propert_claimed = true
              branch_assigned = true
              branch_owned = false
            end
            

            {
              address: each_detail[:address],
              is_vendor_registered: is_vendor_registered,
              invite_sent: invite_sent,
              udprn: each_detail[:udprn],
              branch_owned: branch_owned,
              expiry_date: expiry_date,
              branch_assigned: branch_assigned,
              propert_claimed: propert_claimed,
              vendor_claimed_at: vendor_claimed_at,
              assigned_agent_id: each_detail[:agent_id],
              vanity_url: each_detail[:vanity_url]
            }
          end
          branch_details = { branch_id: branch.id, branch_name: branch.name, branch_logo: branch.image_url }
          result_hash = { results: results, preassigned_count: preassigned_count }
          result_hash.merge!(branch_details)
          render json: result_hash, status: 200
        else
          message = "Sorry, but you can only mailshot vendors with an #{area} postcode district, sector or unit."
          render json: { message: message }, status: 400
        end
      else
        render json: { message: 'The specified branch was not found in the database' }, status: 400
      end
#    else
#      render json: { message: 'Branch authentication failed' }, status: 400
#    end
  end

  ### Display the preemptions for the agents claimed
  ### curl -XGET -H "Authorization: csvna1vmvcssw" 'http://localhost/agents/branches/mailshot/preemptions'
  ### TODO: Add vendor claimed timestamp 
  def branch_mailshot_properties
    agent = @current_user
    branch_id = agent.branch_id
    page_size = 20
    page_offset = (params[:page].to_i - 1)
    page_offset < 0 ? page_offset = 0 : page_offset = page_offset
    results = []

    if params[:count].to_s != 'true'
      results = AddressDistrictRegister.where(branch_id: branch_id).order('created_at DESC').limit(page_size).offset(page_offset*page_size).map do |address|
        {
          udprn: address.udprn,
          is_vendor_registered: address.vendor_registered,
          expired: address.expired,
          expiry_date: address.expiry_date,
          created_at: address.created_at,
          expired: address.expired,
          vendor_claimed_at: address.vendor_claimed_at
        }
      end
      udprns = results.map{|t| t[:udprn] }
  
      bulk_response = PropertyService.bulk_details(udprns.uniq)
  
      bulk_response.each do |each_res|
        index = results.index{ |t| t[:udprn] == each_res[:udprn].to_i }
        results[index][:address] = each_res[:address]
        results[index][:vanity_url] = each_res[:vanity_url]
        results[index][:assigned_agent_id] = each_res[:agent_id].to_i
      end
    else
      results = AddressDistrictRegister.where(branch_id: branch_id).count
    end

    Rails.logger.info("Results hash #{results}")

    render json: results, status: 200
  end

  ### Payment history for agents
  ### curl -XGET -H "Authorization: csvna1vmvcssw" 'http://localhost/agents/mailshot/payment/history'
  def mailshot_payment_history
    agent = @current_user
    branch = agent.branch
    page = params[:page].to_i
    page_size = 20
    results = AddressDistrictRegsiter.where(branch_id: branch.id).group(:payment_group_id).select("max(created_at) as created_at").select("string_agg(udprn::text, ',') as udprns").limit(page_size).offset(page_size.to_i*page).map do |preassigned_property|
      udprns = preassigned_property.udprns.split(',')
      cost = udprns.count.to_f * Agents::Branch::CHARGE_PER_PROPERTY
      {
        payment_time: preassigned_property.created_at,
        udprns: udprns,
        cost: (udprns.count.to_f * Agents::Branch::CHARGE_PER_PROPERTY),
      }
    end
    render json: results, status: 200
  end

  ### Extract buyer's info for agent's properties
  ### curl -XGET 'Authorization: bns6nsk2n' 'http://localhost/agents/property/vendors/info/:udprn'
  def agent_properties_vendor_buying_reqs
    property_details = PropertyDetails.details(params[:udprn].to_i)[:_source]
    attr_list = [:min_beds, :max_beds, :min_baths, :max_baths, :min_receptions, :max_receptions, :property_types,
                 :status, :buying_status, :funding, :biggest_problems, :chain_free, :budget_from, :budget_to, :locations,
                 :mortgage_approval ].map(&:to_s)
    buyer_details = PropertyBuyer.where(vendor_id: property_details[:vendor_id].to_i).select(attr_list).last.as_json
    response = nil

    if buyer_details
      buyer_details['status'] = PropertyBuyer::REVERSE_STATUS_HASH[buyer_details['status']]
      buyer_details['buying_status'] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer_details['buying_status']]
      buyer_details['funding'] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer_details['funding']]
      buyer_details['property_tracking'] = Events::Track.where(udprn: params[:udprn].to_i).select(:id).last.nil?
      response = {}
      (attr_list- ['property_tracking', 'chain_free', 'budget_from', 'budget_to']).each { |t| response["buyer_#{t}"] = buyer_details[t] }
      response['property_tracking'] = buyer_details['property_tracking']
      response['chain_free'] = buyer_details['chain_free']
      response['buyer_min_budget'] = buyer_details['budget_from']
      response['buyer_max_budget'] = buyer_details['budget_to']
    end

    render json: { buyer_details: response }, status: 200
  end

  ### Extract buyer's info for agent's enquiries
  ### curl -XGET 'Authorization: bns6nsk2n' 'http://localhost/agents/enquiries/buyer/info/:buyer_id?udprn=1234567'
  def agent_enquiries_buyer_reqs
    attr_list = [:min_beds, :max_beds, :min_baths, :max_baths, :min_receptions, :max_receptions, :property_types,
                 :status, :buying_status, :funding, :biggest_problems, :chain_free, :budget_from, :budget_to, :locations,
                 :mortgage_approval ].map(&:to_s)
    buyer_details = PropertyBuyer.where(id: params[:buyer_id].to_i).select(attr_list).last.as_json
    response = nil

    if buyer_details
      buyer_details['status'] = PropertyBuyer::REVERSE_STATUS_HASH[buyer_details['status']]
      buyer_details['buying_status'] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer_details['buying_status']]
      buyer_details['funding'] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer_details['funding']]
      buyer_details['property_tracking'] = Events::Track.where(udprn: params[:udprn].to_i).select(:id).last.nil?
      response = {}
      (attr_list- ['property_tracking', 'chain_free', 'budget_from', 'budget_to']).each { |t| response["buyer_#{t}"] = buyer_details[t] }
      response['property_tracking'] = buyer_details['property_tracking']
      response['chain_free'] = buyer_details['chain_free']
      response['buyer_min_budget'] = buyer_details['budget_from']
      response['buyer_max_budget'] = buyer_details['budget_to']
    end
    Rails.logger.info("RESPONSE_#{response}")

    render json: { buyer_details: response }, status: 200
  end

  private

  def authenticate_agent
    if user_valid_for_viewing?('Agent')
      yield
    else
      message = "Sorry, but you do not have permission to view this page" if action_name == 'fetch_invited_properties_for_district'
      message ||= 'Authorization failed'
      render json: { message: message }, status: 401
    end
  end

  def authenticate_agent_and_buyer
    if user_valid_for_viewing?('Agent') || user_valid_for_viewing?('Vendor')
      yield
    else
      message = 'Authorization failed'
      render json: { message: message }, status: 401
    end
  end

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

