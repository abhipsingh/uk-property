class CreateAdPaymentHistories < ActiveRecord::Migration
  def change
    create_table :ad_payment_histories do |t|
      t.string :hash_str, null: false
      t.integer :udprn, null: false
      t.integer :service, null: false
      t.integer :months, null: false
      t.integer :type_of_ad, null: false

      t.timestamp :created_at, null: false
    end
  end
end
