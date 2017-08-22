class CreateStripePayments < ActiveRecord::Migration
  def change
    create_table :stripe_payments do |t|
      t.integer :entity_id
      t.string :entity_type
      t.integer :amount
      t.timestamps null: false
    end
    remove_column(:stripe_payments, :updated_at)
  end
end
