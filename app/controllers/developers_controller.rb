class DevelopersController < ApplicationController
  def search
    klasses = ['Developers::Group', 'Developers::Branch', 'Developers::Company', 'Developers::Branches::Employee']
    klass_map = {
      'Developers::Company' => 'Company',
      'Developers::Branch' => 'Branch',
      'Developers::Group' => 'Group',
      'Developers::Branches::Employee' => 'Agent'
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
  ### curl -XGET 'http://localhost/developers/info/10968961'
  def info_developers
    udprn = params[:udprn]
    details = PropertyDetails.details(udprn.to_i)
    district = details['_source']['district']
    count = Developers::Branches::Employee.joins(:branch).where('developers_branches.district = ?', district).count
    render json: count, status: 200
  end

  #### Information about branches for this district
  #### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo"  'http://localhost/developers/branches/list/:district'
  def list_branches
    vendor = user_valid_for_viewing?('Vendor')
    if !vendor.nil?
      branch_list = Developers::Branch.where(district: params[:district]).select([:id, :name]) 
      render json: branch_list, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Details of the developer
  ### curl -XGET 'http://localhost/developers/employee/1234'
  def developer_details
    developer_id = params[:developer_id]
    developer = Developers::Branches::Employee.find(developer_id)
    developer_details = developer.as_json(methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at, :invited_developers])
    developer_details[:company_id] = developer.branch.company_id
    developer_details[:group_id] = developer.branch.company.group_id
    developer_details[:domain_name] = developer.branch.domain_name
    render json: developer_details, status: 200
  end

  ### Details of the branch
  ### curl -XGET 'http://localhost/developers/branch/9851'
  def branch_details
    branch_id = params[:branch_id]
    branch = Developers::Branch.find(branch_id)
    branch_details = branch.as_json(include: {employees: {methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at, :invited_developers]}}, except: [:verification_hash, :invited_developers])
    branch_details[:company_id] = branch.company_id
    branch_details[:group_id] = branch.company.group.id
    render json: branch_details, status: 200
  end

  ### Details of the company
  ### curl -XGET 'http://localhost/agents/company/6290'
  def company_details
    company_id = params[:company_id]
    company_details = Developers::Company.find(company_id)
    company_details = company_details.as_json(include:  { branches: { include: { employees: {methods: [:active_properties], except: [:password_digest, 
                                          :password, :provider, :uid, :oauth_token, :oauth_expires_at]}}, except: [:verification_hash]}})
    render json: company_details, status: 200
  end

  ### Details of the group
  ### curl -XGET 'http://localhost/agents/group/1'
  def group_details
    group_id = params[:group_id]
    group = Developers::Group.find(group_id)
    group_details = group.as_json(include:  { companies: { include: { branches: { include: { employees: {methods: [:active_properties]}}}}}})
    render json: group_details, status: 200
  end

  ### Add company, branch and group details to a developer
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/developers/register' -d '{ "branch_id" : 9851, "company_id" : 6290, "group_id" : 1, "group_name" :"Dynamic Group", "company_name" : "Dynamic Property Management", "branch_name" : "Dynamic Property Management", "branch_address" : "18 Hope Street, Crook, DL15 9HS", "branch_phone_number" : "9988776655", "branch_email" : "df@fg.com", "branch_website" : "www.dmg.com", "verification_hash" : "$2a$10$E0NsNocTd0getkV7h8GcFuwLlekcyUugcEg9lVXIzADRskrdcyYOu" }'
  def add_developer_details
    branch_id = params[:branch_id].to_i
    branch = Developers::Branch.where(id: branch_id).first
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
    branch = Developers::Branch.where(id: branch_id).last
    if branch
      other_developers = params[:invited_developers]
      branch.invited_developers = branch.invited_developers + (JSON.parse(other_developers) rescue [])
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

  ### Shows the udprns in the branch_id which are not verified and Green along with 
  ###  email ids and ids of the assigned agents
  ### curl  -XGET  'http://localhost/developers/23/udprns/verify'
  def verify_developer_udprns
    employee_id = params[:id].to_i
    employee = Developers::Branches::Employee.where(id: employee_id).first
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
      developers = Developers::Branches::Employee.where(branch_id: branch.id).select([:email, :id])
      render json: { properties: body, developers: developers }, status: 200
    else
      render json: { message: 'Developer not found with the given id' }, status: 400
    end
  end

  ### Invite vendor to verify the udprn
  ### curl  -XPOST -H  "Content-Type: application/json"  'http://localhost/developers/23/udprns/10968961/verify' -d '{ "developer_id": 25, "vendor_email" : "test@prophety.co.uk" }'
  def invite_vendor_developer
    udprn = params[:udprn].to_i
    original_developer = Developers::Branches::Employee.find(params[:developer_id].to_i)
    developer = Developers::Branches::Employee.find(params[:developer_id].to_i)
    if original_developer.branch_id == developer.branch_id
      developer_id = params[:developer_id].to_i
      vendor_email = params[:vendor_email]
      Developers::Branches::Employee.find(developer_id).send_vendor_email(vendor_email, udprn)
      render json: {message: 'Message sent successfully'}, status: 200
    else
      raise 'Branch id doesnt match'
    end
  rescue Exception => e
   render json: {message: "#{e.message} " }, status: 400
  end

  ### Get the developer info who sent the mail to the vendor
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/invite/udprns/10968961/developers/info?verification_hash=$2a$10$rPk93fpnhYE6lnaUqO/mquXRFT/65F7ab3iclYAqKXingqTKOcwni' -d '{ "password" : "new_password" }'
  def info_for_developer_verification
    verification_hash = params[:verification_hash]
    udprn = params[:udprn]
    hash_obj = VerificationHash.where(hash_value: verification_hash, udprn: udprn.to_i).last
    if hash_obj
      developer = Developers::Branches::Employee.where(id: hash_obj.entity_id).last
      if developer
        password = params[:password]
        agent.password = password
        agent.save!
        render json: { details: {developer_name: developer.name, developer_id: developer.id, developer_email: developer.email, udprn: udprn } }, status: 200
      else
        render json: { message: 'Agent not found' }, status: 400
      end
    else
      render json: { message: 'hash not found' }, status: 400
    end
  end

  ### Verify the developer as the intended developer and udprn as the correct udprn
  ### curl  -XPOST -H  "Content-Type: application/json" 'http://localhost/vendors/udprns/10968961/developers/23/verify'
  def verify_developer_for_developer_claimed_property
    udprn = params[:udprn].to_i
    agent_id = params[:developer_id].to_i
    property_status_type = params[:property_status_type]
    response, status = PropertyService.new(udprn).update_details({ property_status_type: property_status_type, verification_status: true, developer_id: developer_id, developer_status: 2 })
    response['message'] = "Developer verification successful." unless status.nil? || status!=200
    render json: response, status: status
  rescue Exception => e
    Rails.logger.info("VERIFICATION_FAILURE_#{e}")
    render json: { message: 'Verification failed due to some error' }, status: 400
  end

  #### Edit details of a branch
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost/developers/branches/9851/edit' -d '{ "branch" : { "name" : "Jackie Bing", "address" : "8 The Precinct, Main Road, Church Village, Pontypridd, HR1 1SB", "phone_number" : "9873628232", "website" : "www.google.com", "image_url" : "some random url", "email" : "a@b.com"  } }'
  def edit_branch_details
    branch = Developers::Branch.where(id: params[:id].to_i).last
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
    company = Developers::Company.where(id: params[:id].to_i).last
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
    group = Developers::Group.where(id: params[:id].to_i).last
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

end

