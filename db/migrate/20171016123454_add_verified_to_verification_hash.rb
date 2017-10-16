class AddVerifiedToVerificationHash < ActiveRecord::Migration
  def change
    add_column(:verification_hashes, :verified, :boolean, default: false)
  end
end
