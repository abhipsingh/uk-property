class UsersController < ApplicationController
  ### curl -XGET http://localhost/users/details?email=example@mail.com&user_type=Vendor
  def details
    user_type_map = {
      'Agent' => Agents::Branches::AssignedAgent,
      'Vendor' => Vendor,
      'User'   => PropertyBuyer
    }
    klass = user_type_map[params[:user_type]] 
    details = klass.find_by_email(params[:email]).as_json(only: [:id, :name, :email, :image_url])
    render json: {  details: details }, status: 200
  rescue Exception => e
    render json: { message: "User not found with #{params[:user_type]}" }, status: 400
  end
end
