class SocialSignupNotifyUserWorker
  include SesEmailSender
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(user_email, provider)
    template_data = { vendor_email_address: user_email }
    provider == 'facebook' ? template_name = 'vendor_fb_registration' : template_name = 'vendor_linkedin_registration'
    self.class.send_email(user_email, template_name, self.class.to_s, template_data)
  end

end

