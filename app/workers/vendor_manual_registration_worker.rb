class VendorManualRegistrationWorker
  include Sidekiq::Worker
  include SesEmailSender
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(vendor_email, link)
    template_data = { vendor_email_address: vendor_email, vendor_manual_registration_first_time_login_url: link }
    self.class.send_email(vendor_email, 'vendor_registration_manual', self.class.to_s, template_data)
  end

end

