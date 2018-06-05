class SesSendBulkEmailWorker
  include Sidekiq::Worker
  include SesEmailSender
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(buyer_emails, sender, body, subject)
    template_data = { subject: subject, agent_email: sender } 
    SesService.send_bulk_emails(buyer_emails, sender, body, subject)
  end

end

