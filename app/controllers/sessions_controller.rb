### Main controller which handles the requests to show
### index pages and the mobile offers page

class SessionsController < ApplicationController
  def create
    # Rails.logger.info(params[:facebook])
    req_params = params[:facebook]
    user_type = params[:user_type]
    user_otp = params['otp']

    ### Verify OTP within one hour
    totp = ROTP::TOTP.new("base32secret3232", interval: 1)
    otp_verified = totp.verify_with_drift(user_otp, 3600, Time.now)

    if otp_verified
      if params[:token].nil? || params[:token].length < 10
        render json: { message: 'Please pass valid oauth token credentials' } , status: 400
      elsif user_type && ['Vendor', 'Buyer', 'Agent', 'Developer'].include?(user_type)
        user_type_map = {
          'Agent' => 'Agents::Branches::AssignedAgent',
          'Vendor' => 'Vendor',
          'Buyer' => 'PropertyBuyer',
          'Developer' => 'Agents::Branches::AssignedAgent'
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
          user.is_first_agent = user.calculate_is_first_agent
          user.save!
          agent_id = user.id
          udprns = InvitedAgent.where(email: user.email).pluck(:udprn)
          client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
          udprns.compact.map { |udprn|  PropertyDetails.update_details(client, udprn, { agent_id: agent_id, agent_status: 2 }) }
        elsif user_type == 'Developer'
          user.is_first_agent = user.calculate_is_first_agent
          user.save!
          developer_id = user.id
          udprns = InvitedDeveloper.where(email: user.email).pluck(:udprn)
          udprns.compact.map { |t| PropertyService.new(t).update_details({ developer_id: developer_id, developer_status: 2 })}
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
    else
      render json: { message: 'OTP Failure' }, status: 400
    end
  end

  ### Sends a sms to a mobile number to check it later
  ### curl -XPOST  -H "Content-Type: application/json" 'http://localhost/send/otp'  -d '{ "mobile" : "+446474255672"  }'
  ### TODO: This is an open api. Checks needs to be put in place to prevent abuse of this api.
  def send_otp_to_number
    sns = Aws::SNS::Client.new(region: "us-east-1", access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_secret_key)
    mobile = params[:mobile]
    totp = ROTP::TOTP.new("base32secret3232", interval: 1)
    #totp.verify_with_drift(totp, 3600, Time.now+3600)
    mobile_otp = MobileOtpVerify.create!(mobile: mobile, otp: totp.now)
    message = "You have received an OTP from Prophety. Enter the OTP #{mobile_otp.otp} to proceed"
    sns.publish({ phone_number: mobile, message: message })
    render json: { message: 'OTP sent successfully' }, status: 200
  end

  ### Used to create a first time agent
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost:8000/register/agents/' -d '{ "agent" : { "name" : "Jackie Bing", "email" : "jackie.bing@friends.com", "mobile" : "9873628231", "password" : "1234567890", "branch_id" : 9851, "otp":678651 } }'
  def create_agent
    agent_params = params[:agent].as_json
    agent_params.delete('company_id')
    agent_params = agent_params.with_indifferent_access
    status = 200
    verification_hash = VerificationHash.where(email: agent_params['email']).last
    if verification_hash
      if Agents::Branches::AssignedAgent.exists?(email: agent_params["email"])
        response = {"message" => "Error! Agent already registered. Please login", "status" => "FAILURE"}
        status = 400
        render json: response, status: status
      else

        first_branch_cond = (Agents::Branches::AssignedAgent.where(branch_id: agent_params[:branch_id]).count == 0)
        otp_verified = true if first_branch_cond
  
        ### Verify OTP within one hour
        totp = ROTP::TOTP.new("base32secret3232", interval: 1)
        user_otp = agent_params['otp']
        otp_verified ||= totp.verify_with_drift(user_otp, 3600, Time.now)
        agent_params.delete("otp")

        if otp_verified
  
          agent = Agents::Branches::AssignedAgent.new(agent_params)
          ### To calculate if it is the first agent
          agent.is_first_agent = agent.calculate_is_first_agent

          if agent.save && VerificationHash.where(email: agent_params['email']).update_all({verified: true})
            command = AuthenticateUser.call(agent_params['email'], agent_params['password'], Agents::Branches::AssignedAgent)
            udprns = InvitedAgent.where(email: agent_params['email']).pluck(:udprn)
            client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
            udprns.compact.map{ |udprn| PropertyDetails.update_details(client, udprn, { agent_id: agent.id, agent_status: 2 }) }
            agent.password = nil
            agent.password_digest = nil
            agent_details = agent.as_json
            agent_details['group_id'] = agent.branch && agent.branch.agent ? agent.branch.agent.group_id : nil
            agent_details['company_id'] = agent.branch && agent.branch.agent ? agent.branch.agent.id : nil
            response = {"auth_token" => command.result, "details" => agent_details, "status" => "SUCCESS"}
            render json: response, status: 200
          else
            response = {"message" => "Error in saving agent. Please check username and password.", "status" => "FAILURE"}
            status = 500
            render json: response, status: status
          end

        else
          render json: { message: 'OTP Failure' }, status: 400
        end
      end
    else
      render json: { message: 'No verification hash found' }, status: 400
    end    
  end

  ### Used to create a first time developer
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/register/developer/' -d '{ "developer" : { "name" : "Jackie Bing", "email" : "jackie.bing@friends.com", "mobile" : "9873628231", "password" : "1234567890", "branch_id" : 9851, "otp":345621 } }'
  def create_developer
    developer_params = params[:developer].as_json
    developer_params.delete('company_id')
    developer_params = agent_params.with_indifferent_access
    status = 200
    verification_hash = VerificationHash.where(email: developer_params['email']).last
    if verification_hash 
      if Agents::Branches::AssignedAgent.exists?(email: developer_params['email'])
        response = {'message' => 'Error! Developer already registered. Please login', 'status' => 'FAILURE'}
        status = 400
        render json: response, status: status
      elsif verification_hash.verified
        render json: { message: 'Verification hash already used. Please repeat the signup process' }, status: 200
      else

        first_branch_cond = Agents::Branches::AssignedAgent.unscope(where: :is_developer)
                                                           .where(branch_id: developer_params[:branch_id])
                                                           .where(is_developer: true)
                                                           .count
        otp_verified = true if first_branch_cond == 0
        ### Verify OTP within one hour
        totp = ROTP::TOTP.new("base32secret3232", interval: 1)
        user_otp = developer_params['otp']
        otp_verified ||= totp.verify_with_drift(user_otp, 3600, Time.now)
        developer_params.delete("otp")

        if otp_verified

          developer = Agents::Branches::AssignedAgent.new(developer_params)
          developer.is_first_agent = developer.calculate_is_first_agent
          developer.is_developer = true

          if developer.save! && VerificationHash.where(email: developer_params['email']).update_all({verified: true})
            command = AuthenticateUser.call(developer_params['email'], developer_params['password'], Agents::Branches::AssignedAgent)
            udprns = InvitedDeveloper.where(email: developer_params['email']).pluck(:udprn)
            udprns.map { |t| PropertyService.new(t).update_details({ agent_id: developer.id, is_developer: true })}
            developer.password = nil
            developer.password_digest = nil
            developer_details = developer.as_json
            developer_details.delete(:password)
            developer_details.delete(:password_digest)
            # developer_details['group_id'] = developer.branch && developer.branch.developer ? developer.branch.developer.group_id : nil
            # developer_details['company_id'] = developer.branch && developer.branch.developer ? developer.branch.developer.id : nil
            response = {"auth_token" => command.result, "details" => developer_details, "status" => "SUCCESS"}
            render json: response, status: 200
          else
            response = {'message' => 'Error in saving developer. Please check username and password.', 'status' => 'FAILURE'}
            status = 500
            render json: response, status: status
          end
        else
          render json: { message: 'OTP Failure' }, status: 400
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

  #### Used for login for a developer
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/login/developers/' -d '{ "developer" : { "email" : "jackie.bing@friends.com","password" : "1234567890" } }'
  def login_developer
    developer_params = params[:developer].as_json
    command = AuthenticateUser.call(developer_params['email'], developer_params['password'], Agents::Branches::AssignedAgent)
    render json: { auth_token: command.result }
  end

  ### Used to create a first time vendor upon the invitation of an agent
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/register/vendors/' -d '{ "vendor" : { "name" : "Jackie Bing", "email" : "jackie.bing1@friends.com", "mobile" : "9873628231", "password" : "1234567890", "otp":234541 } }'
  def create_vendor
    vendor_params = params[:vendor].as_json
    
    if Vendor.where(email: vendor_params['email']).last
      render json: { message: 'Vendor with the same email id already exists in the db' }, status: 400
    else
      verification_hash = VerificationHash.where(email: vendor_params['email']).last
      ### Verify OTP within one hour
      totp = ROTP::TOTP.new("base32secret3232", interval: 1)
      user_otp = vendor_params['otp']
      otp_verified = totp.verify_with_drift(user_otp, 3600, Time.now)
  
      if otp_verified
        if verification_hash
          vendor_params['name'] = '' if vendor_params['name']
          vendor_params.delete("hash_value")
          vendor_params.delete("otp")
          vendor = Vendor.new(vendor_params)
          vendor.save!
          buyer = PropertyBuyer.new(vendor_params)
          buyer.vendor_id = vendor.id
          buyer.email_id = buyer.email
          buyer.account_type = 'a'
          VerificationHash.where(email: vendor_params['email']).update_all({verified: true})
          buyer.save!
          vendor.buyer_id = buyer.id
          vendor.save!
          command = AuthenticateUser.call(vendor_params['email'], vendor_params['password'], Vendor)
          render json: { auth_token: command.result, details: vendor.as_json } 
        else
          render json: { message: 'No verification hash exists' }, status: 400
        end
      else
        render json: { message: 'OTP Failure'}, status: 400
      end
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
      vendor_details = @current_user.as_json
      yearly_quote_count = Agents::Branches::AssignedAgents::Quote.where(vendor_id: @current_user.id).where("created_at > ?", 1.year.ago).group(:property_id).select("count(id)").to_a.count
      vendor_details[:yearly_quote_count] = yearly_quote_count
      vendor_details[:quote_limit] = Agents::Branches::AssignedAgents::Quote::VENDOR_LIMIT
      render json: vendor_details, status: 200
    end
  end

  ### Get agent details for authentication token
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4LCJleHAiOjE0ODQxMjExNjN9.CisFo3nsAKkoQME7gxH42wiF-pMuwRCa6VGY8dPHbSA" 'http://localhost/details/agents'
  def agent_details
    authenticate_request
    if @current_user && !@current_user.is_developer
      details = @current_user.details
      render json: details, status: 200
    end
  end

  ### Get agent details for authentication token
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4LCJleHAiOjE0ODQxMjExNjN9.CisFo3nsAKkoQME7gxH42wiF-pMuwRCa6VGY8dPHbSA" 'http://localhost/details/developers'
  def developer_details
    authenticate_request('Developer')
    if @current_user && @current_user.is_developer
      details = @current_user.as_json
      details.delete("oauth_token")
      details.delete("oauth_expires_at")
      details.delete("password")
      details.delete("password_digest")
      render json: details, status: 200
    end
  end

  ### Send an email with a hash url to reset password
  ### curl -XPOST   -H "Content-Type: application/json"  'http://localhost/forgot/password' -d '{ "email" : "test15@prophety.co.uk", "profile_type" : "Vendor" }'
  def forgot_password
    profile_type_map = {
      'Agent' => 'Agents::Branches::AssignedAgent',
      'Developer' => 'Agents::Branches::AssignedAgent',
      'Vendor' => 'Vendor',
      'Buyer' => 'PropertyBuyer'
    }
    profile_klass = profile_type_map[params[:profile_type]]
    if profile_klass
      entity = profile_klass.constantize.where(email: params[:email]).first
      if entity
        salt_str = "#{profile_klass}_#{entity.id}_password_reset" 
      	hash = BCrypt::Password.create salt_str
        verification_hash = VerificationHash.create!(entity_id: entity.id, entity_type: profile_klass, hash_value: hash, email: params[:email])
        AgentMailer.send_password_reset_email({'email' => params[:email], 'hash' => hash, 'profile' => params[:profile_type]}).deliver_now
        render json: { message: 'Password reset mail sent successfully' }, status: 200
      else
        render json: { message: "Email doesn't exist on the server"}, status: 400
      end
    else
      render json: { message: "Profile type doesn't exist"}, status: 400
    end
  end

  ### Reset the password given the verification hash
  ### curl -XPOST   -H "Content-Type: application/json"  'http://localhost/reset/password' -d '{ "hash" : "$2a$10$qQ1kaM.RFeSXGFpcRr0awezhyWemxOtoCqXv5NW3v2d3TDCsc3sy", "password" : "1234567890" }'
  def reset_password
    verification_hash = VerificationHash.where(hash_value: params[:hash]).last
    if verification_hash && !verification_hash.verified
      password = params[:password]
      klass = verification_hash.entity_type
      entity = klass.constantize.where(email: verification_hash.email).first
      if entity
        entity.password = password
        if entity.class.to == 'Vendor'
          buyer = PropertyBuyer.where(vendor_id: entity.id).last
          buyer.password = password
          buyer.save!
        elsif  entity.class.to_s == 'PropertyBuyer'
          vendor = Vendor.where(buyer_id: entity.id).last
          vendor.password = password
          vendor.save!
        end
        verification_hash.verified = true
        if entity.save! && verification_hash.save!
          render json: { message: 'Password reset successfully' }, status: 200
        else
          render json: { message: 'Password not able to save successfully. Please try again with a new link' }, status: 200
        end
      else
        render json: { message: 'The account does not exist anymore' }, status: 400
      end
    else
      render json: { message: 'Verification hash is invalid' }, status: 400
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
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/buyers/signup/' -d '{ "email"  : "jackie.bing1@gmail.com", "udprn":12345678, "rent":true }'
  def buyer_signup
    email = params[:email].strip
    if PropertyBuyer.where(email: email).count == 0
      salt_str = email
      verification_hash = BCrypt::Password.create salt_str
      VerificationHash.create(hash_value: verification_hash, email: email, entity_type: 'PropertyBuyer')
      email_link = 'http://sleepy-mountain-35147.herokuapp.com/auth?verification_hash=' + verification_hash  + '&user_type=Buyer'
      email_link += '&udprn=' + params[:udprn].to_i if params[:udprn]
      email_link += '&rent=true' if params[:rent].to_s == 'true'
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
    sql = VerificationHash.where(hash_value: hash_value).select(:email).select("CASE WHEN entity_type='PropertyBuyer' THEN 'Buyer' WHEN entity_type='Agents::Branches::AssignedAgent' THEN 'Agent' WHEN entity_type='Developer' THEN 'Developer'  ELSE 'Vendor' END as entity_type ").to_sql
    details = ActiveRecord::Base.connection.execute(sql)
    if details.first['entity_type'] == 'Agent'
      is_agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(is_developer: true, email: details.first['email']).last.nil?
      details.first['entity_type'] = 'Developer' if !is_agent
    end
    render json: { hash_details: details }, status: 200
  end

  ### Used to create a first time buyer
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost/register/buyers/' -d '{ "buyer" : { "email" : "jackie.bing1@gmail.com", "password" : "1234567890", hash_value: "$2a$10$3YUduTL7Hc.vBzGIXDe4mOv8sVy4YrM3/TsGcnohBYeSu/izRq4K6", "otp":346721 } }'
  def create_buyer
    buyer_params = params[:buyer].as_json
    
    if PropertyBuyer.where(email: buyer_params['email']).last
      render json: { message: 'A buyer with the same email id already exists' }, status: 400
    else
      buyer_params[:email_id] = buyer_params['email']
      buyer_params[:account_type] = 'S'
      buyer_params.delete("hash_value")
      vendor = Vendor.new(email: buyer_params['email'], first_name: buyer_params['first_name'], last_name: buyer_params['last_name'])
      vendor.full_name = vendor.first_name.to_s + ' ' + vendor.last_name.to_s
      vendor.password = buyer_params['password']
      vendor.mobile = buyer_params['mobile']
      verification_hash = VerificationHash.where(email: buyer_params['email']).last
  
      ### Verify OTP within one hour
      totp = ROTP::TOTP.new("base32secret3232", interval: 1)
      user_otp = buyer_params['otp']
      otp_verified = totp.verify_with_drift(user_otp, 3600, Time.now)
      buyer_params.delete("otp")
      buyer = PropertyBuyer.new(buyer_params)
  
      if otp_verified
        if buyer.save! && vendor.save! && VerificationHash.where(email: buyer_params['email']).update_all({verified: true})
          buyer.vendor_id = vendor.id
          vendor.buyer_id = buyer.id
          vendor.save && buyer.save
          render json: { message: 'New buyer created', details: buyer.as_json }, status: 200
        else
          render json: { message: 'Buyer creation failed', errors: buyer.errors }, status: 400
        end
      else
        render json: { message: 'OTP Failure' }, status: 400
      end
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
    authenticate_request('Buyer', ['Buyer', 'Agent'])
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

  def authenticate_request(klass='Agent', klasses=[])
    if !klasses.empty?
      klasses.each {|klass| @current_user ||= AuthorizeApiRequest.call(request.headers, klass).result }
    else
      @current_user = AuthorizeApiRequest.call(request.headers, klass).result 
    end
    render json: { error: 'Not Authorized' }, status: 401 if @current_user.nil?
  end

  def current_user
     reset_session
     user_type_map = {
      'Agent' => 'Agents::Branches::AssignedAgent',
      'Vendor' => 'Vendor',
      'Buyer' => 'PropertyBuyer',
      'Developer' => 'Agents::Branches::AssignedAgent'
     } 
    if session[:user_type] && ['Vendor', 'Buyer', 'Agent', 'Developer'].include?(session[:user_type])
      @current_user ||= session[:user_type].constantize.unscope(where: :is_developer).where(id: session[:user_id]).last
    end
  end

end

