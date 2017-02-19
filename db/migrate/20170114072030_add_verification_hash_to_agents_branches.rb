class AddVerificationHashToAgentsBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :verification_hash, :text)
    add_index(:agents_branches, :verification_hash, {unique: true})
  end
end
