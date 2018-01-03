class CreateMobileOtpVerifies < ActiveRecord::Migration
  def change

    create_table :mobile_otp_verifies do |t|
      t.string :mobile
      t.integer :otp
      t.boolean :verified, default: false
      t.timestamp :created_at, null: false
    end

  end
end

