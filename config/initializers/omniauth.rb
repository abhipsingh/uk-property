# Rails.application.config.middleware.use OmniAuth::Builder do
#   provider :twitter, ENV['twitter_api_key'], ENV['twitter_api_secret']
#   provider :facebook, ENV['facebook_app_id'], ENV['facebook_app_secret'],
#     scope: 'public_profile', info_fields: 'id,name,email'
# end

#http://127.0.0.1:3000/auth/twitter/callback

OmniAuth.config.logger = Rails.logger
#Rails.application.config.middleware.use OmniAuth::Builder do
# provider :facebook, ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_APP_SECRET'], scope: 'email', info_fields: 'name,email,picture', image_size: 'large'
#end
