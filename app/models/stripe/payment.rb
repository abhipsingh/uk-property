class Stripe::Payment < ActiveRecord::Base
  def self.table_name
    'stripe_payments'
  end

  USER_TYPES = {
    'Agent' => 1,
    'Vendor' => 2,
    'Buyer' => 3
  }
end
