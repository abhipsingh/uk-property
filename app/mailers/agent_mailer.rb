class AgentMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    @url  = 'http://example.com/login'
    mail(to: user.agent_email, subject: "Welcome to Prophety")
  end

end