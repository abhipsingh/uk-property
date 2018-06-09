class AddUniqueOtpToMobileOtpVerify < ActiveRecord::Migration
  def change
    add_index(:mobile_otp_verify, :otp, unique: true)
  end
end

