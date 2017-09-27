Rails.configuration.stripe = {
    :publishable_key => ENV['PUBLISHABLE_KEY'],
    :secret_key      => ENV['SECRET_KEY']
}

Stripe.api_key = ENV['SECRET_KEY']
Rails.configuration.stripe_signature_secret = ENV['STRIPE_SIGNATURE_SECRET']

