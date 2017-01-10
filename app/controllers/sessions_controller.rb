### Main controller which handles the requests to show
### index pages and the mobile offers page
class SessionsController < ApplicationController
  def create
    req_params = request.env["omniauth.params"]
    if req_params['user_type'] && ['Vendor', 'Buyer', 'Agent'].include?(req_params['user_type'])
      user_type = req_params['user_type']
      user_type_map = {
        'Agent' => 'Agents::Branches::AssignedAgent',
        'Vendor' => 'Vendor',
        'Buyer' => 'PropertyBuyer'
      }
      user = user_type_map[user_type].constantize.from_omniauth(env["omniauth.auth"])
      session[:user_id] = user.id
      session[:user_type] = user_type
      user_details = user.as_json
      # user_details['uid'] = '1173320732780684'
      user_details.delete('password')
      user_details.delete('password_digest')
      render json: { message: 'Successfully created a session', user_type: user_details, details: user.as_json }, status: 200
    else
      render json: { message: 'Not able to find user' }, status: 400
    end
  end

  ### Used to create a first time agent
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/register/agents/' -d '{ "agent" : { "name" : "Jackie Bing", "email" : "jackie.bing@friends.com", "mobile" : "9873628231", "password" : "1234567890" } }'
  def create_agent
    agent_params = params[:agent].as_json
    agent = Agents::Branches::AssignedAgent.new(agent_params)
    agent.save!
    command = AuthenticateUser.call(agent_params['email'], agent_params['password'], Agents::Branches::AssignedAgent)
    agent.password = nil
    agent.password_digest = nil
    render json: { auth_token: command.result, details: agent.as_json } 
  end

  #### Used for login for an agent
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/login/agents/' -d '{ "agent" : { "email" : "jackie.bing@friends.com","password" : "1234567890" } }'
  def login_agent
    agent_params = params[:agent].as_json
    command = AuthenticateUser.call(agent_params['email'], agent_params['password'], Agents::Branches::AssignedAgent)
    render json: { auth_token: command.result }
  end

  ### Get agent details for authentication token
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4LCJleHAiOjE0ODQxMjExNjN9.CisFo3nsAKkoQME7gxH42wiF-pMuwRCa6VGY8dPHbSA" 'http://localhost/details/agents'
  def agent_details
    authenticate_request
    if @current_user
      details = @current_user.as_json
      details.delete('password')
      details.delete('password_digest')
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

  private
  def authenticate_request 
    @current_user = AuthorizeApiRequest.call(request.headers, 'Agent').result 
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
