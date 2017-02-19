class CreateVerificationHashes < ActiveRecord::Migration
  def change
    create_table :verification_hashes do |t|
      t.integer :entity_id
      t.string :entity_type
      t.string :hash
      t.string :email

      t.timestamps null: false
    end
  end
end
