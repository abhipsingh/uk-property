Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, 'pVfFj5MA1AfybxRPHQGHxCSw8', 'At4pcUks6OGLSOKhzWNkJ2lwylaBzTT3fszdZuntLsUUnU9SYL'
  provider :facebook, '799848696825702', '40926286e96c098321f6505ad28e9ce3',
    scope: 'public_profile', info_fields: 'id,name,email'
end

#http://127.0.0.1:3000/auth/twitter/callback
