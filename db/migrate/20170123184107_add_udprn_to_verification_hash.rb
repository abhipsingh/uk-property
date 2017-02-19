class AddUdprnToVerificationHash < ActiveRecord::Migration
  def change
    add_column(:verification_hashes, :udpnr, :integer)
  end
end
