Clearance.configure do |config|
  config.mailer_sender = "reply@example.com"
  config.user_model = 'Users::EmailUser'
  config.routes = true
  config.allow_sign_up = true
end
