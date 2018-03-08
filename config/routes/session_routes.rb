Rails.application.routes.draw do

  ### Registers an agent for the first time and issues a web token for the agent
  post 'register/agents',                                       to: 'sessions#create_agent'

  ### Login for an agent when an email and a password is provided
  post 'login/agents',                                          to: 'sessions#login_agent'

  ### Registers a vendor for the first time and issues a web token for the agent
  post 'register/vendors',                                      to: 'sessions#create_vendor'

  ### Login for a vendor when an email and a password is provided
  post 'login/vendors',                                         to: 'sessions#login_vendor'

  ### Login for a developer when an email and a password is provided
  post 'login/developers',                                      to: 'sessions#login_developer'

  ### Details for a vendor when a token is provided
  get 'details/vendors',                                        to: 'sessions#vendor_details'

  ### Details for a developer when a token is provided
  get 'details/developers',                                     to: 'sessions#developer_details'

  ### Sends an email to the buyer for registration
  post 'buyers/signup',                                         to: 'sessions#buyer_signup'

  ### Sends an email to the vendor for registration
  post 'vendors/signup',                                        to: 'sessions#vendor_signup'

  ### Gets the details of the verification hash sent to the emails of vendor and buyers
  get 'users/all/hash',                                         to: 'sessions#hash_details'

  ### Registers a buyer for the first time and issues a web token for the agent
  post 'register/buyers',                                       to: 'sessions#create_buyer'

  ### Login for a vendor when an email and a password is provided
  post 'login/buyers',                                          to: 'sessions#login_buyer'

  ### Details for a vendor when a token is provided
  get 'details/buyers',                                         to: 'sessions#buyer_details'

  ### Info about the verification hash(Verified or Not)
  get 'sessions/hash/verified',                                 to: 'sessions#verification_hash_verified'

  ### For all the users, to reset their password if they have done an email based signup
  post '/forgot/password',                                      to: 'sessions#forgot_password'

  ### Reset password for any user
  post '/reset/password',                                       to: 'sessions#reset_password'

  ### Sends an SMS to a mobile number to check it later
  post '/send/otp',                                             to: 'sessions#send_otp_to_number'

  ### Destroys a session
  get 'signout',                                                to: 'sessions#destroy',   as: 'signout'

end

