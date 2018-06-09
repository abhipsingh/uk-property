class SnsOtpWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false # job will be discarded immediately if failed

  def perform(mobile)
    sns = Aws::SNS::Client.new(region: "us-west-2", access_key_id: Rails.configuration.aws_access_key, secret_access_key: Rails.configuration.aws_access_secret)
    totp = ROTP::TOTP.new("base32secret3232", interval: 1)
    
    #totp.verify_with_drift(totp, 3600, Time.now+3600)
    otp, mobile_otp = nil
    otp = totp.now
    loop do
      begin
        mobile_otp = MobileOtpVerify.create!(mobile: mobile, otp: otp)
        break
      rescue Exception
        interval = (1..10).to_a.sample*0.1
        sleep(interval)
      end
    end
    message = "You have received an OTP from Prophety. Enter the OTP #{otp} to proceed"
    sns.publish({ phone_number: mobile, message: message })
  end
end

