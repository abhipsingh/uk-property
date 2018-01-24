class AuthenticateUser 
  prepend SimpleCommand 
  def initialize(email, password, klass) 
    @email = email 
    @password = password 
    @klass = klass
  end 

  def call 
    current_user = user
    JsonWebToken.encode(user_id: current_user.id, klass: current_user.class.to_s) if current_user
  end 

  private 
  attr_accessor :email, :password

  def user
    user = @klass.unscope(where: :is_developer).where(email: email).last
    return user if user && user.authenticate(password) 
    errors.add :user_authentication, 'invalid credentials'
    nil
  end 
end

