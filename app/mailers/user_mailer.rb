class UserMailer < ApplicationMailer
	def welcome_email(user)
  	@user = user
  	@url  = 'http://example.com/login'
  	mail(to: @user.agent_email, subject: "Welcome to Prophety #{@user.name}")
	end

  def signup_email(hash)
    @email = hash[:email]
    @hash = @hash
    @link = hash[:link]
    mail(to: @email, subject: "User Registration #{@email}")
  end

end
