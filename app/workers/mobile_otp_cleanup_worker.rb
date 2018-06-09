class MobileOtpCleanupWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform
    MobileOtpVerify.where("created_at > ? ", MobileOtpVerify::OTP_EXPIRY_PERIOD.ago - 30.minutes).delete_all
  end
  
end

