class DeveloperMailer < ApplicationMailer
  
  def welcome_email(user)
    @user = user
    @url  = 'http://example.com/login'
    mail(to: user.developer_email, subject: "Welcome to Prophety")
  end
end

