class UserMailerPreview < ActionMailer::Preview
  def sample_mail_preview
    UserMailer.welcome_email(Agents::Branch.first)
  end
end