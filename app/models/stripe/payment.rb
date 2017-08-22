class Stripe::Payment < ActiveRecord::Base
  def self.table_name
    'stripe_payments'
  end
end
