class RenameColumnUdpnrToUdprnInVerificationHashes < ActiveRecord::Migration
  def change
    rename_column(:verification_hashes, :udpnr, :udprn)
  end
end
