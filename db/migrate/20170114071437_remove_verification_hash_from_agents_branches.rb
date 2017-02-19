class RemoveVerificationHashFromAgentsBranches < ActiveRecord::Migration
  def change
    remove_column(:agents_branches, :verification_hash)
  end
end
