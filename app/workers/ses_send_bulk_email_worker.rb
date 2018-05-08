class SesSendBulkEmailWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(buyer_emails, sender, body, subject)
    SesService.send_bulk_emails(buyer_emails, sender, body, subject)
  end
end

