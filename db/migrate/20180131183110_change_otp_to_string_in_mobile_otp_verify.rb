class ChangeOtpToStringInMobileOtpVerify < ActiveRecord::Migration
  def change
    change_column(:mobile_otp_verifies, :otp, :string)
  end
end
