class AddUniqueOtpToMobileOtpVerify < ActiveRecord::Migration
  def change
    add_index(:mobile_otp_verifies, :otp, unique: true)
  end
end

