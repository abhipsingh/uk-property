class MobileOtpVerify < ActiveRecord::Base
  OTP_EXPIRY_PERIOD = 30.minutes
end

