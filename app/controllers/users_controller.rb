class UsersController < ApplicationController
  ### curl -XGET 'http://localhost/users/details?email=example@mail.com&user_type=Vendor'
  def details
    user_type_map = {
      'Agent' => Agents::Branches::AssignedAgent,
      'Vendor' => Vendor,
      'Buyer'   => PropertyBuyer
    }
    klass = user_type_map[params[:user_type]]
    details = klass.find_by_email(params[:email]).as_json(only: [:id, :name, :email, :image_url]) if params[:email]
    details = klass.find(params[:id]).as_json(only: [:id, :name, :email, :image_url]) if params[:id]
    render json: {  details: details }, status: 200
  rescue Exception => e
    render json: { message: "User not found with #{params[:user_type]}" }, status: 400
  end

  def postcode_area_panel_details
    res = {}
    if params[:debug]
      res = User.postcode_area_panel_details
    end
    render json: res, status: 200
  end

end
