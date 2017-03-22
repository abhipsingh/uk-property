class AuthenticateUser 
  prepend SimpleCommand 
  def initialize(email, password, klass) 
    @email = email 
    @password = password 
    @klass = klass
  end 

  def call 
    JsonWebToken.encode(user_id: user.id) if user 
  end 

  private 
  attr_accessor :email, :password

  def user
    user = @klass.find_by_email(email) 
    return user if user && user.authenticate(password) 
    errors.add :user_authentication, 'invalid credentials'
    nil
  end 
end

