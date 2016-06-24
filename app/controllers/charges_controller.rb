class ChargesController < ApplicationController
  def new
    # this will remain empty unless you need to set some instance variables to pass on
    @amount = 100
  end
 
  def create
    # Amount in cents
    params[:stripeAmount] = 100
    amount = params[:stripeAmount].to_i * 100
 
    # Create the customer in Stripe
    customer = Stripe::Customer.create(
      email: params[:stripeEmail],
      card: params[:stripeToken]
    )
 
    # Create the charge using the customer data returned by Stripe API
    charge = Stripe::Charge.create(
      customer: customer.id,
      amount: amount,
      description: 'Rails Stripe customer',
      currency: 'usd'
    )
 
    # place more code upon successfully creating the charge
  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to charges_path
    flash[:notice] = "Please try again"
  end
end