class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users_email_users do |t|
      t.timestamps null: false
      t.string :email, null: false
      t.string :encrypted_password, limit: 128, null: false
      t.string :confirmation_token, limit: 128
      t.string :remember_token, limit: 128, null: false
    end

    add_index :users_email_users, :email
    add_index :users_email_users, :remember_token
  end
end
