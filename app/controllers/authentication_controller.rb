class AuthenticationController < ApplicationController 
  skip_before_action :authenticate_request 

  def authenticate 
    user_type_map = {
      'Agent' => Agents::Branches::AssignedAgent,
      'Vendor' => Vendor,
      'User'   => PropertyBuyer
    }

    klass = user_type_map[params[:user_type]] 
    render json: { error: 'Incorrect User type provided' }, status: 401 unless klass
    command = AuthenticateUser.call(params[:email], params[:password], klass)
    if command.success? 
      details = klass.find_by_email(params[:email]).as_json(only: [:id, :name, :email, :image_url])
      render json: { auth_token: command.result, details: details } 
    else 
      render json: { error: command.errors }, status: :unauthorized 
    end 
  end
end

