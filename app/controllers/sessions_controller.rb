### Main controller which handles the requests to show
### index pages and the mobile offers page

class SessionsController < ApplicationController
  def create
    # Rails.logger.info(params[:facebook])
    req_params = params[:facebook]
    user_type = params[:user_type]
    if params[:token].nil? || params[:token].length < 10
      render json: { message: 'Please pass valid oauth token credentials' } , status: 400
    elsif user_type && ['Vendor', 'Buyer', 'Agent'].include?(user_type)
      user_type_map = {
        'Agent' => 'Agents::Branches::AssignedAgent',
        'Vendor' => 'Vendor',
        'Buyer' => 'PropertyBuyer'
      }
      req_params[:token] = params[:token]
      user = user_type_map[user_type].constantize.from_omniauth(req_params)
      
      if user_type == 'Vendor' 
        buyer = PropertyBuyer.from_omniauth(req_params)
        buyer.vendor_id = user.id
        user.buyer_id = buyer.id
        user.save! && buyer.save!
      elsif user_type == 'Buyer'
        vendor = Vendor.from_omniauth(req_params)
        vendor.buyer_id = user.id
        user.vendor_id = vendor.id
        user.save! && vendor.save!
      end

      if user_type == 'Agent'
        agent_id = user.id
        udprns = InvitedAgent.where(email: user.email).pluck(:udprn)
        client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
        udprns.map { |udprn|  PropertyDetails.update_details(client, udprn, { agent_id: agent_id, agent_status: 2 }) }
      end

      session[:user_id] = user.id
      session[:user_type] = user_type
      user_details = user.as_json
      # user_details['uid'] = '1173320732780684'
      user_details.delete('password')
      user_details.delete('password_digest')
      #Rails.logger.info(req_params)
      command = AuthenticateUser.call(req_params['email'], "12345678", user_type_map[user_type].constantize)
      render json: { message: 'Successfully created a session', auth_token: command.result, details: user.as_json }, status: 200
    else
      render json: { message: 'Not able to find user' }, status: 400
    end
  end

  ### Used to create a first time agent
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost:8000/register/agents/' -d '{ "agent" : { "name" : "Jackie Bing", "email" : "jackie.bing@friends.com", "mobile" : "9873628231", "password" : "1234567890", "branch_id" : 9851 } }'
  def create_agent
    agent_params = params[:agent].as_json
    agent_params.delete('company_id')
    status = 200
    verification_hash = VerificationHash.where(email: agent_params['email']).last
    if verification_hash
      if Agents::Branches::AssignedAgent.exists?(email: agent_params["email"])
        response = {"message" => "Error! Agent already registered. Please login", "status" => "FAILURE"}
        status = 400
      else
        agent = Agents::Branches::AssignedAgent.new(agent_params)
        verification_hash.verified = true
        if agent.save && verification_hash.save!
          command = AuthenticateUser.call(agent_params['email'], agent_params['password'], Agents::Branches::AssignedAgent)
          udprns = InvitedAgent.where(email: agent_params['email']).pluck(:udprn)
          client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
          udprns.map { |udprn|  PropertyDetails.update_details(client, udprn, { agent_id: agent.id, agent_status: 2 }) }
          agent.password = nil
          agent.password_digest = nil
          agent_details = agent.as_json
          agent_details['group_id'] = agent.branch && agent.branch.agent ? agent.branch.agent.group_id : nil
          agent_details['company_id'] = agent.branch && agent.branch.agent ? agent.branch.agent.id : nil
          response = {"auth_token" => command.result, "details" => agent_details, "status" => "SUCCESS"}
        else
          response = {"message" => "Error in saving agent. Please check username and password.", "status" => "FAILURE"}
          status = 500
          render json: response, status: status
        end
      end
    else
      render json: { message: 'No verification hash found' }, status: 400
    end    
  end

  #### Used for login for an agent
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/login/agents/' -d '{ "agent" : { "email" : "jackie.bing@friends.com","password" : "1234567890" } }'
  def login_agent
    agent_params = params[:agent].as_json
    command = AuthenticateUser.call(agent_params['email'], agent_params['password'], Agents::Branches::AssignedAgent)
    render json: { auth_token: command.result }
  end

  ### Used to create a first time vendor upon the invitation of an agent
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/register/vendors/' -d '{ "vendor" : { "name" : "Jackie Bing", "email" : "jackie.bing1@friends.com", "mobile" : "9873628231", "password" : "1234567890" } }'
  def create_vendor
    vendor_params = params[:vendor].as_json
    verification_hash = VerificationHash.where(email: vendor_params['email']).last
    if verification_hash
      vendor_params['name'] = '' if vendor_params['name']
      vendor_params.delete("hash_value")
      vendor = Vendor.new(vendor_params)
      vendor.save!
      buyer = PropertyBuyer.new(vendor_params)
      buyer.vendor_id = vendor.id
      buyer.email_id = buyer.email
      buyer.account_type = 'a'
      verification_hash.verified = true
      verification_hash.save!
      buyer.save!
      vendor.buyer_id = buyer.id
      vendor.save!
      command = AuthenticateUser.call(vendor_params['email'], vendor_params['password'], Vendor)
      render json: { auth_token: command.result, details: vendor.as_json } 
    else
      render json: { message: 'No verification hash exists' }, status: 400
    end
  end

  #### Used for login for a vendor
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/login/vendors/' -d '{ "vendor" : { "email" : "jackie.bing1@friends.com","password" : "1234567890" } }'
  def login_vendor
    vendor_params = params[:vendor].as_json
    command = AuthenticateUser.call(vendor_params['email'], vendor_params['password'], Vendor)
    render json: { auth_token: command.result }
  end

  ### Get vendor details
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo3LCJleHAiOjE0ODUxODUwMTl9.7drkfFR5AUFZoPxzumLZ5TyEod_dLm8YoZZM0yqwq6U" 'http://localhost/details/vendors'
  def vendor_details
    authenticate_request('Vendor')
    if @current_user
      render json: @current_user.as_json, status: 200
    end
  end

  ### Get agent details for authentication token
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4LCJleHAiOjE0ODQxMjExNjN9.CisFo3nsAKkoQME7gxH42wiF-pMuwRCa6VGY8dPHbSA" 'http://localhost/details/agents'
  def agent_details
    authenticate_request
    if @current_user
      details = @current_user.details
      render json: details, status: 200
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path
  end

  def new
    redirect_to '/auth/facebook'
  end

  ### Sends an email to the buyer's email address for registration
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/buyers/signup/' -d '{ "email"  : "jackie.bing1@gmail.com" }'
  def buyer_signup
    email = params[:email].strip
    if PropertyBuyer.where(email: email).count == 0
      salt_str = email
      verification_hash = BCrypt::Password.create salt_str
      VerificationHash.create(hash_value: verification_hash, email: email, entity_type: 'PropertyBuyer')
      email_link = 'http://sleepy-mountain-35147.herokuapp.com/auth?verification_hash=' + verification_hash  + '&user_type=Buyer'
  
      params_hash = { verification_hash: verification_hash, email: email, link: email_link }
      UserMailer.signup_email(params_hash).deliver_now
      render json: { message:  'Please check your email id and click on the link sent'}, status: 200
    else
      render json: { message:  'Email has already been registered'}, status: 400
    end
  end

  ### Sends an email to the vendor's email address for registration
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/vendors/signup/' -d '{ "email"  : "jackie.bing2@gmail.com" }'
  def vendor_signup
    email = params[:email].strip
    if Vendor.where(email: email).count == 0
      salt_str = email
      verification_hash = BCrypt::Password.create salt_str
      VerificationHash.create(hash_value: verification_hash, email: email, entity_type: 'Vendor')
      email_link = 'http://sleepy-mountain-35147.herokuapp.com/auth?verification_hash=' + verification_hash + '&user_type=Vendor'
      params_hash = { verification_hash: verification_hash, email: email, link: email_link }
      VendorMailer.signup_email(params_hash).deliver_now
      render json: { message:  'Please check your email id and click on the link sent'}, status: 200
    else 
      render json: { message:  'Email has already been registered'}, status: 400
    end
  end

  ### Given a verification hash, get the email address for vendor and property buyers
  ### curl -XGET  'http://localhost/users/all/hash?value=$2a$10$3YUduTL7Hc.vBzGIXDe4mOv8sVy4YrM3/TsGcnohBYeSu/izRq4K6'
  def hash_details
    hash_value = params[:value]
    sql = VerificationHash.where(hash_value: hash_value).select(:email).select("CASE WHEN entity_type='PropertyBuyer' THEN 'Buyer' WHEN entity_type='Agents::Branches::AssignedAgent' THEN 'Agent' ELSE 'Vendor' END as type ").to_sql
    details = ActiveRecord::Base.connection.execute(sql)
    render json: { hash_details: details }, status: 200
  end

  ### Used to create a first time buyer
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost/register/buyers/' -d '{ "buyer" : { "email" : "jackie.bing1@gmail.com", "password" : "1234567890", hash_value: "$2a$10$3YUduTL7Hc.vBzGIXDe4mOv8sVy4YrM3/TsGcnohBYeSu/izRq4K6" } }'
  def create_buyer
    buyer_params = params[:buyer].as_json
    buyer_params[:email_id] = buyer_params['email']
    buyer_params[:account_type] = 'S'
    buyer_params.delete("hash_value")
    vendor = Vendor.new(email: buyer_params['email'], first_name: buyer_params['first_name'], last_name: buyer_params['last_name'])
    vendor.full_name = vendor.first_name.to_s + ' ' + vendor.last_name.to_s
    vendor.password = buyer_params['password']
    vendor.mobile = buyer_params['mobile']
    buyer = PropertyBuyer.new(buyer_params)
    verification_hash = VerificationHash.where(email: buyer_params['email']).last
    verification_hash.verified = true if verification_hash
    if buyer.save! && vendor.save! && verification_hash.save!
      buyer.vendor_id = vendor.id
      vendor.buyer_id = buyer.id
      vendor.save && buyer.save
      render json: { message: 'New buyer created', details: buyer.as_json }, status: 200
    else
      render json: { message: 'Buyer creation failed', errors: buyer.errors }, status: 400
    end
  end

  #### Used for login for a buyer
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/login/buyers/' -d '{ "buyer" : { "email" : "jackie.bing1@gmail.com","password" : "1234567890" } }'
  def login_buyer
    buyer_params = params[:buyer].as_json
    command = AuthenticateUser.call(buyer_params['email'], buyer_params['password'], PropertyBuyer)
    render json: { auth_token: command.result }
  end

  ### Get agent details for authentication token
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/details/buyers'
  def buyer_details
    authenticate_request('Buyer')
    if @current_user
      details = @current_user.as_json
      details['buying_status'] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[details['buying_status']]
      details['funding'] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[details['funding']]
      details['status'] = PropertyBuyer::REVERSE_STATUS_HASH[details['status']]
      render json: details, status: 200
    end
  end
  
  ### Get verification hash info (verified or not)
  ### curl -XGET  'http://localhost/sessions/hash/verified/:hash'
  def verification_hash_verified
    verified = false
    hash = VerificationHash.where(hash_value: params[:hash]).last
    verified = hash.verified if hash
    render json: { verified: verified }, status: 200
  end

  private
  def authenticate_request(klass='Agent')
    @current_user = AuthorizeApiRequest.call(request.headers, klass).result 
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user 
  end

  def current_user
     reset_session
      user_type_map = {
        'Agent' => 'Agents::Branches::AssignedAgent',
        'Vendor' => 'Vendor',
        'Buyer' => 'PropertyBuyer'
       } 
    if session[:user_type] && ['Vendor', 'Buyer', 'Agent'].include?(session[:user_type])
      @current_user ||= session[:user_type].constantize.find(session[:user_id])
    end
  end

end
