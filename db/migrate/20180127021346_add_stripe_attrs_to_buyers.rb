class AddStripeAttrsToBuyers < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :stripe_customer_id, :string)
    add_column(:property_buyers, :premium_expires_at, :datetime)
  end
end

