class AddIndexesToVerificationHash < ActiveRecord::Migration
  def change
    remove_column(:verification_hashes, :hash)
    add_column(:verification_hashes, :hash_value, :text)
    add_index(:verification_hashes, :hash_value, {unique: true})
  end
end
