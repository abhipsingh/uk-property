class AuthorizeApiRequest 
  prepend SimpleCommand 
  def initialize(headers = {}, user_type=nil) 
    @headers = headers 
    @user_type = user_type
  end 

  def call
    user_type_map = {
      'Agent' => Agents::Branches::AssignedAgent,
      'Vendor' => Vendor,
      'Buyer'   => PropertyBuyer
    }
    klass = user_type_map[@user_type]
    user(klass) 
  end 

  private 
  attr_reader  :headers 

  def user(klass)
    #Rails.logger.info "user = #{@user.inspect}"
    @user ||= errors.add(:user_type, 'Invalid user type') unless klass
    @user ||= klass.where(id: decoded_auth_token[:user_id]).last if decoded_auth_token && klass
    @user ||= errors.add(:token, 'Invalid token') && nil
    #Rails.logger.debug "user = #{@user.inspect}"
    #Rails.logger.debug "errors = #{errors.inspect}"
    @user
  end 

  def decoded_auth_token
    @decoded_auth_token ||= JsonWebToken.decode(http_auth_header) 
  end 

  def http_auth_header 
    if headers['Authorization'].present? 
      return headers['Authorization'].split(' ').last
    else 
      errors.add(:token, 'Missing token') 
    end 
    return nil 
  end 
end

