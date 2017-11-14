class AddChargeIdToStripePayments < ActiveRecord::Migration
  def change
    add_column(:stripe_payments, :charge_id, :string)
    add_column(:stripe_payments, :udprn, :integer)
    remove_column(:stripe_payments, :entity_type)
    add_column(:stripe_payments, :entity_type, :integer)
  end
end
