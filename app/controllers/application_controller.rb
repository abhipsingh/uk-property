### Base controller
class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # before_action :authenticate_property_user!, except: [:follow]
  protect_from_forgery with: :exception
  #before_action :authenticate_request
  attr_reader :current_user
  skip_before_action :verify_authenticity_token
  before_action :cors_allow_all

  LOCAL_EC2_URL = 'http://127.0.0.1:9200'
  ES_EC2_URL = Rails.configuration.remote_es_url

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || (root_path)
  end

  private
  def authenticate_request 
    @current_user = AuthorizeApiRequest.call(request.headers, params[:user_type]).result 
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user 
  end
  def cors_allow_all
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, PUT, DELETE, GET, OPTIONS'
    headers['Access-Control-Request-Method'] = '*'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
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
