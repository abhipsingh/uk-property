class DevelopersController < ApplicationController

  #### Predictions api for developers
  #### curl -XGET 'http://localhost/developers/predictions?str=a'
  def search
    klasses = ['Agents::Group', 'Agents::Branch', 'Agent', 'Agents::Branches::AssignedAgent']
    klass_map = {
      'Agent' => 'Company',
      'Agents::Branch' => 'Branch',
      'Agents::Group' => 'Group',
      'Agents::Branches::AssignedAgent' => 'Agent'
    }
    search_results = klasses.map { |e|  e.constantize.unscope(where: :is_developer).where(is_developer: true).where("lower(name) LIKE ?", "#{params[:str].downcase}%").limit(10).as_json }
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
  ### curl -XGET 'http://localhost/developers/info/10968961'
  def local_info
    udprn = params[:udprn]
    details = PropertyDetails.details(udprn.to_i)
    district = details['_source']['district']
    count = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(is_developer: true).joins(:branch).where('agents_branches.district = ?', district).count
    render json: count, status: 200
  end

  #### Information about branches for this district
  #### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo"  'http://localhost/developers/branches/list/:district'
  def list_branches
    vendor = user_valid_for_viewing?('Vendor', ['Vendor', 'Agent'])
    ### Either a vendor or a premium developer
    if !vendor.nil? && (vendor.klass.to_s == 'Vendor' || (vendor.klass.to_s == 'Agent' && vendor.is_developer ))
      branch_list = Agents::Branch.unscope(where: :is_developer).where(is_developer: true).where(district: params[:district]).select([:id, :name]) 
      render json: branch_list, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Details of the developer
  ### curl -XGET 'http://localhost/developers/employee/1234'
  def developer_details
    developer_id = params[:developer_id]
    developer = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(is_developer: true, id: developer_id).last
    developer_details = developer.as_json(methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at])
    developer_details[:company_id] = developer.branch.company_id
    developer_details[:group_id] = developer.branch.company.group_id
    developer_details[:domain_name] = developer.branch.domain_name
    render json: developer_details, status: 200
  end

  ### Details of the branch
  ### curl -XGET 'http://localhost/developers/branch/9851'
  def branch_details
    branch_id = params[:branch_id]
    branch = Agents::Branch.unscope(where: :is_developer).where(is_developer: true, id: branch_id).last
    branch_details = branch.as_json(include: {employees: {methods: [:active_properties], except: [:password_digest, 
                                              :password, :provider, :uid, :oauth_token, :oauth_expires_at]}}, except: [:verification_hash])
    branch_details[:company_id] = branch.company_id
    branch_details[:group_id] = branch.company.group.id
    render json: branch_details, status: 200
  end

  ### Details of the company
  ### curl -XGET 'http://localhost/developers/company/6290'
  def company_details
    company_id = params[:company_id]
    company_details = Agent.unscope(where: :is_developer).where(is_developer: true, id: company_id).last
    company_details = company_details.as_json(include:  { branches: { include: { employees: {methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at]}}, except: [:verification_hash]}})
    render json: company_details, status: 200
  end

  ### Details of the group
  ### curl -XGET 'http://localhost/developers/group/1'
  def group_details
    group_id = params[:group_id]
    group = Agents::Group.unscope(where: :is_developer).where(is_developer: true, id: group_id).last
    group_details = group.as_json(include:  { companies: { include: { branches: { include: { employees: {methods: [:active_properties]}}}}}})
    render json: group_details, status: 200
  end

  ### Add company, branch and group details to a developer
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/developers/register' -d '{ "branch_id" : 9851, "company_id" : 6290, "group_id" : 1, "group_name" :"Dynamic Group", "company_name" : "Dynamic Property Management", "branch_name" : "Dynamic Property Management", "branch_address" : "18 Hope Street, Crook, DL15 9HS", "branch_phone_number" : "9988776655", "branch_email" : "df@fg.com", "branch_website" : "www.dmg.com", "verification_hash" : "$2a$10$E0NsNocTd0getkV7h8GcFuwLlekcyUugcEg9lVXIzADRskrdcyYOu" }'
  def add_developer_details
    branch_id = params[:branch_id].to_i
    branch = Agents::Branch.unscope(where: :is_developer).where(is_developer: true, id: branch_id).first
    company = branch.company
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

  #### Invite the other developers to register
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/developers/invite' -d '{"branch_id" : 9851, "invited_developers" : "\[ \{ \"branch_id\" : 9851, \"company_id\" : 6290, \"email\" : \"test@prophety.co.uk\" \} ]" }'
  def invite_developers_to_register
    branch_id = params[:branch_id].to_i
    branch = Agents::Branch.unscope(where: :is_developer).where(is_developer: true, id: branch_id).last
    if branch
      other_developers = branch.invited_agents
      invited_developers = JSON.parse(params[:invited_developers]) rescue []
      branch.invited_agents = invited_developers
      branch.send_emails(is_developer=true)
      branch.invited_agents = other_developers + invited_developers
      branch.save
      render json: { message: 'Branch with given emails invited' }, status: 200
    else
      render json: { message: 'Branch with given branch_id doesnt exist' }, status: 400
    end
  end

  ### Shows the udprns in the branch_id which are not verified and Green along with 
  ###  email ids and ids of the assigned agents
  ### curl  -XGET  'http://localhost/developers/23/udprns/verify'
  def verify_developer_udprns
    employee_id = params[:id].to_i
    employee = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(is_developer: true, id: employee_id).first
    if employee && employee.branch
      branch = employee.branch
      district = branch.district
      filtered_params = {}
      filtered_params[:district] = district
      filtered_params[:property_status_type] = 'Green'
      filtered_params[:verification_status] = false
      search_api = PropertySearchApi.new(filtered_params: filtered_params)
      search_api.apply_filters
      body, status = search_api.fetch_data_from_es
      developers = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(is_developer: true, branch_id: branch.id).select([:email, :id])
      render json: { properties: body, developers: developers }, status: 200
    else
      render json: { message: 'Developer not found with the given id' }, status: 400
    end
  end

  def edit_branch_details
    branch = Agents::Branch.unscope(where: :is_developer).where(is_developer: true, id: params[:id].to_i).last
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
  ### `curl -XPOST -H "Content-Type: application/json"  'http://localhost/developers/companies/6290/edit' -d '{ "company" : { "name" : "Jackie Bing", "address" : "8 The Precinct, Main Road, Church Village, Pontypridd, HR1 1SB", "phone_number" : "9873628232", "website" : "www.google.com", "image_url" : "some random url", "email" : "a@b.com"  } }'`
  def edit_company_details
    company = Agent.unscope(where: :is_developer).where(is_developer: true, id: params[:id].to_i).last
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
    group = Agents::Group.unscope(where: :is_developer).where(is_developer: true, id: params[:id].to_i).last
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

  ### Edit developer employee details
  ### `curl -XPOST -H "Content-Type: application/json"  'http://localhost/developers/employees/6292/edit' -d '{ "developer" : { "name" : "Jackie Bing", "phone_number" : "9873628232", "image_url" : "some random url", "email" : "a@b.com"  } }'`
  def edit_developer_details
    developer_id = params[:developer_id].to_i
    developer = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(is_developer: true, id: developer_id).last
    developer_params = params[:developer].as_json
    developer.first_name = developer_params['first_name'] if developer_params['first_name']
    developer.last_name = developer_params['last_name'] if developer_params['last_name']
    developer.email = developer_params['email'] if developer_params['email']
    developer.mobile = developer_params['mobile'] if developer_params['mobile']
    developer.image_url = developer_params['image_url'] if developer_params['image_url']
    developer.branch_id = developer_params['branch_id'] if developer_params['branch_id']
    developer.password = developer_params['password'] if developer_params['password']
    developer.save!
    ### TODO: DeveloperUpdateWorker
#    AgentUpdateWorker.new.perform(developer.id)
    ### TODO: Update all properties containing this developer
    update_hash = { agent_id: developer_id }
    render json: {message: 'Updated successfully', details: developer}, status: 200  if developer.save!
  rescue 
    render json: {message: 'Failed to Updated successfully'}, status: 200
  end


  ### Invited developers history for branches
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/developers/list/invited/developers'
  def branch_specific_invited_developers
    agent = user_valid_for_viewing?('Developer')
    if !agent.nil?
      branch_id = agent.branch_id
      invited_developers = InvitedDeveloper.where(branch_id: branch_id).select([:email, :created_at])
      render json: invited_developers, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end


  ### Verify the property's basic attributes and attach the crawled property to a udprn(new build)
  ### Done when the developer attaches the udprn to the property
  ### curl  -XPOST -H  "Content-Type: application/json"  'http://localhost/developers/properties/verify' -d '{ "properties" : [{"property_type" : "Barn conversion", "beds" : 1,  "baths" : 1, "receptions" : 1, "udprn" : 340620, "assigned_developer_email" :  "residentevil293@prophety.co.uk", "features" : ["Bla bla meh"], "description" : "ipsum lorem", "floorplan_urls": ["www.blablameh.com"] }]}'
  def verify_properties_through_developer
    user = user_valid_for_viewing?('Developer')
    if user && user.is_developer
      developer_id = params[:developer_id].to_i
      properties = params[:properties]
      response = {}
      response = status = nil
      response_arr = []
      if properties.is_a?(Array)
        developer_service = DeveloperService.new(developer_id)
        properties.each do |each_property|
          property_attrs = {
            property_status_type: 'Green',
            verification_status: true,
            property_type: each_property[:property_type],
            beds: each_property[:beds].to_i,
            baths: each_property[:baths].to_i,
            receptions: each_property[:receptions].to_i,
            details_completed: false,
            claimed_on: Time.now.to_s,
            claimed_by: 'Agent',
            is_developer: true,
            udprn: each_property[:udprn],
            additional_features: each_property[:features],
            description: each_property[:description],
            floorplan_urls: each_property[:floorplan_urls],
            agent_id: user.id
          }
          assigned_developer_email = each_property[:assigned_developer_email]
          begin
            NewPropertyUploadHistory.create!(property_type: each_property[:property_type], beds: each_property[:beds].to_i, baths: each_property[:baths].to_i, receptions: each_property[:receptions].to_i, udprn: each_property[:udprn], features: each_property[:features], description: each_property[:description], floorplan_urls: each_property[:floorplan_urls], developer_id: user.id)
            response, status = developer_service.upload_property_details(property_attrs, assigned_developer_email, user.branch_id, user.id)
            message = 'Successfully uploaded a property'
            resp = { udprn: each_property[:udprn], message: message, status: 'SUCCESS' }
            response_arr.push(resp)
          rescue ActiveRecord::RecordNotUnique => e
            message = 'This property was already uploaded'
            resp = { udprn: each_property[:udprn],  message: message, status: 'FAILURE' }
            response_arr.push(resp)
          end
        end
      else
        response = 'Properties param should be in an array'
        status = 400
      end

      render json: response_arr, status: status
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### History of properties which have been manually uploaded by the developers
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/developers/upload/history/properties'
  def upload_property_history
    agent = user_valid_for_viewing?('Developer')
    if !agent.nil?
      results = []
      NewPropertyUploadHistory.where(developer_id: agent.id).order('created_at ASC').each do |uploaded_property|
        details = PropertyDetails.details(uploaded_property.udprn)[:_source]
        result = {
          beds: uploaded_property.beds,
          baths: uploaded_property.baths,
          receptions: uploaded_property.receptions,
          employee_email: uploaded_property.assigned_agent_email,
          property_type: uploaded_property.property_type,
          udprn: uploaded_property.udprn,
          address: details[:address],
          created_at: uploaded_property.created_at,
          features: uploaded_property.features,
          description: uploaded_property.description,
          floorplan_urls: uploaded_property.floorplan_urls
        }
        results.push(result)
      end
      render json: results, status: 200
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
      result
    else
      AuthorizeApiRequest.call(request.headers, klass).result
    end
  end

end

