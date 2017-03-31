Rails.application.routes.draw do
  get 'welcome/index'
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'welcome#index'

  ### Test view
  get 'agents/test/view',                    to: 'agents#test_view'

  ## JWT based authentication
  post 'authenticate', to: 'authentication#authenticate'

  ## Get user details
  get 'users/details', to: 'users#details'

  ###### ENQUIRIES ####################################################
  #####################################################################
  #####################################################################
  #####################################################################
  ### Post events to the server
  post 'events/new',                         to: 'events#process_event'

  ### Get property enquiries
  get 'property/enquiries/:property_id',     to: 'events#property_enquiries'

  ### Get fresh enquiries for agents
  get 'agents/enquiries/new/:agent_id',      to: 'events#agent_new_enquiries'

  ### Get all enquiries for agents grouped by property
  get 'agents/enquiries/property/:agent_id', to: 'events#agent_enquiries_by_property'

  ### Get buyer enquiries
  get 'buyers/enquiries/:buyer_id',          to: 'events#buyer_enquiries'

  ### Get all recently changed to Green properties for quotes for Agents
  get 'agents/properties/recent/quotes',     to: 'events#recent_properties_for_quotes'

  ### Get all recently changed to Green properties for quotes for Agents
  get 'agents/properties/recent/claims',     to: 'events#recent_properties_for_claim'

  ### Get all stats about the properties for the concerned agents
  get 'agents/enquiries/properties',         to: 'events#property_enquiries'

  ### Get all properties quicklinks for the queried agent_id, or branch or group or company id
  get 'agents/quicklinks/properties',        to: 'events#quicklinks'

  ### Get all properties quicklinks for the queried agent_id, or branch or group or company id
  get 'agents/properties',                   to: 'events#detailed_properties'

  ### Request to unsubscribe a buyer for a particular event for a udprn
  get 'events/unsubscribe',                   to: 'events#unsubscribe'
  #####################################################################
  #####################################################################
  #####################################################################
  ###### QUOTES #######################################################
  #####################################################################
  #####################################################################
  #####################################################################
  ### Post events to the server
  post 'quotes/new',                       to: 'quotes#new'

  ### Post new quotes for a property. Done by a vendor
  post 'quotes/property/:udprn',           to: 'quotes#new_quote_for_property'

  #### When a vendor clicks the submit button
  post 'quotes/submit/:quote_id',          to: 'quotes#submit'

  #### For an agent, claim this property
  post 'events/property/claim/:udprn',     to: 'events#claim_property'
  #####################################################################
  #####################################################################
  #####################################################################

  ########### Routes for the vendors enquiries and buyer interest and other
  ##### sections
  #####################################################################
  #####################################################################
  
  ### For a property get all his detailed quotes for a specific property
  get 'property/quotes/agents/:udprn',      to: 'quotes#quotes_per_property'

  ### For a property get all the stats about the previous prices
  get 'property/prices/:udprn',             to: 'properties#historic_pricing'

  ### For a property get all the stats about the enquiries
  get 'enquiries/property/:udprn',          to: 'properties#enquiries'
  #####################################################################
  #####################################################################
  #####################################################################
  #####################################################################
  #####################################################################
  #### The routes defined in the following section belong to the ######
  #### different data types required by the buyer intent        ######

  ### For a property get all the data regarding buyer activity
  get 'property/interest/:udprn',           to: 'properties#interest_info'

  ### For a property get all the data regarding supply of similar properties
  get 'property/supply/:udprn',             to: 'properties#supply_info'

  ### For a property get all the data regarding demand of similar properties
  get 'property/demand/:udprn',             to: 'properties#demand_info'

  ### For a property get all the data regarding buyer intent of similar properties
  get 'property/buyer/intent/:udprn',       to: 'properties#buyer_intent_info'


  #### PIE Charts routes

  ### Buyer profile stats route
  get 'property/buyer/profile/stats/:udprn',to: 'properties#buyer_profile_stats'

  ### Stats regarding the qualifying stage of buyers of the property for the agents
  get 'property/agent/stage/rating/stats/:udprn', to: 'properties#agent_stage_and_rating_stats'


  #### Ranking routes
  get 'property/ranking/stats/:udprn',        to: 'properties#ranking_stats'

  #### Buyer history event routes
  get 'property/history/enquiries/:buyer_id', to: 'properties#history_enquiries'


  #####################################################################
  #####################################################################
  #####################################################################
  #### Agents routes for assigned agents details panel
  get 'agents/agent/:assigned_agent_id',                       to: 'agents#assigned_agent_details'


  #### Agents routes for branch details
  get 'agents/branch/:branch_id',                               to: 'agents#branch_details'

  #### Agents routes for agent details
  get 'agents/company/:company_id',                             to: 'agents#company_details'

  #### Agents routes for agent group details
  get 'agents/group/:group_id',                                 to: 'agents#group_details'

  #### Agents routes for search any of agent, group, branch or assigned agents by name
  get 'agents/predictions',                                     to: 'agents#search'

  #### Agents routes for search any of agent, group, branch or assigned agents by name
  post 'agents/register',                                       to: 'agents#add_agent_details'

  #### Invite other agents to register as well
  post 'agents/invite',                                         to: 'agents#invite_agents_to_register'

  #### Edit agents details 
  post 'agents/:id/edit',                                       to: 'agents#edit'

  #### Shows details of a specific property owned by a vendor
  get 'vendors/properties/details/:vendor_id',                  to: 'vendors#property_details'

  #### Edit vendor details 
  post 'vendors/:id/edit',                                      to: 'vendors#edit'
  
  #### Shows all the properties owned by a vendor
  get 'vendors/properties/:vendor_id',                          to: 'vendors#properties'

  #### Gets all the properties speicific to a postcode or building attributes
  get 'properties/search/claim',                                to: 'properties#properties_for_claiming'

  #### Edit basic details of a property
  post 'properties/claim/basic/:udprn/edit',                    to: 'properties#edit_basic_details'

  #### Edit basic details of a buyer
  post 'buyers/:id/edit',                                       to: 'buyers#edit_basic_details'

  ### Registers an agent for the first time and issues a web token for the agent
  post 'register/agents',                                       to: 'sessions#create_agent'

  ### Login for an agent when an email and a password is provided
  post 'login/agents',                                          to: 'sessions#login_agent'

  ### Registers a vendor for the first time and issues a web token for the agent
  post 'register/vendors',                                      to: 'sessions#create_vendor'

  ### Login for a vendor when an email and a password is provided
  post 'login/vendors',                                         to: 'sessions#login_vendor'

  ### Details for a vendor when a token is provided
  get 'details/vendors',                                        to: 'sessions#vendor_details'

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

  ### Details for a vendor when a token is provided
  post 'buyers/:id/edit',                                       to: 'property_buyers#edit'

  ### Details for an agent when a token is provided
  get 'details/agents',                                         to: 'sessions#agent_details'

  ### Verify the udprns and invite the vendors
  get 'agents/:id/udprns/verify',                               to: 'agents#verify_udprns'

  ### Invite vendors by sending them an email
  post 'agents/:agent_id/udprns/:udprn/verify',                 to: 'agents#invite_vendor'

  ### get info about the agents which invited the vendor who is registering to verify
  get 'vendors/invite/udprns/:udprn/agents/info',               to: 'agents#info_for_agent_verification'

  ### verify info about the agents which invited the vendor who is registering to verify
  post 'vendors/udprns/:udprn/agents/:agent_id/verify',         to: 'agents#verify_agent'

  ### verify info about the properties which invited the vendor who is registering to verify
  post 'vendors/udprns/:udprn/verify',                          to: 'agents#verify_property'

  ### Get a presigned url for every image to be uploaded on S3
  get 's3/upload/url',                                          to: 's3#presigned_url'

  ### Verify that a upload happened
  get 's3/verify/upload',                                       to: 's3#verify_upload'

  ### For the agent, when he authorizes also make him attach his properties to the udprn
  get 'agents/:id/udprns/attach/verify',                        to: 'agents#verify_udprn_to_crawled_property'

  ### For any vendor, claim an unknown udprn
  post 'properties/udprns/claim/:udprn',                        to: 'properties#claim_udprn'

  ### Get the info about agents for a district
  get 'agents/info/:udprn',                                     to: 'agents#info_agents'

  ### Get the info about agents for a district
  get ':udprn/valuations/last/details',                         to: 'agents#last_valuation_details'

  ### Edit branch details
  post 'branches/:id/edit',                                     to: 'agents#edit_branch_details'  

  ### Edit branch details
  post 'companies/:id/edit',                                    to: 'agents#edit_company_details' 


  ### Edit group details
  post 'groups/:id/edit',                                       to: 'agents#edit_group_details' 


  ### Edit property details
  post 'properties/:udprn/edit/details',                        to: 'properties#edit_property_details'



  #####################################################################
  #####################################################################
  #####################################################################
  #####################################################################
  #####################################################################
  
  get '/auth/:provider/callback', to: 'sessions#create'
  get 'properties/new/:udprn/short', to: 'properties#short_form'
  get 'postcodes/search', to: 'matrix_view#search_postcode'
  get 'addresses/search', to: 'matrix_view#search_address'
  get 'properties/:udprn/edit', to: 'properties#edit'
  get 'crawled_properties/:id/show', to: 'crawled_properties#show'
  get 'crawled_properties/search', to: 'crawled_properties#search'
  get 'crawled_properties/search_results', to: 'crawled_properties#search_results'
  get 'addresses/matrix_view', to: 'matrix_view#matrix_view'
  get 'addresses/predictions', to: 'matrix_view#predictive_search'
  get 'addresses/predictions/results', to: 'matrix_view#get_results_from_hashes'
  get 'properties/claim/short/callback', to: 'properties#claim_property'
  post 'properties/claim/short', to: 'properties#claim_property'
  post 'properties/profile/submit', to: 'properties#complete_profile'
  get 'properties/sign/confirm', to: 'properties#signup_after_confirmation'
  post 'properties/sign/confirm', to: 'properties#property_status'
  post 'properties/change/status', to: 'properties#custom_agent_service'
  post 'properties/agents/services', to: 'properties#final_quotes'
  namespace :api do
    namespace :v0 do
      get  'properties/search',                      to: 'property_search#search'
      get  'agents/search',                          to: 'agents#search'
      get  'ads/availability',                       to: 'vendor_ad#ads_availablity'
      get  'locations/:id/version',                  to: 'vendor_ad#correct_version'
      post 'ads/payments/new',                       to: 'vendor_ad#new_payment'
      post 'ads/availability/update',                to: 'vendor_ad#update_availability'
      post 'properties',                             to: 'property_search#new_property'
      post 'property_users/update/udprns',           to: 'property_search#update_viewed_flats'
      post 'property_users/update/udprns/shortlist', to: 'property_search#update_shortlisted_udprns'
      post 'vendors/update/property_users',          to: 'property_search#notify_vendor_of_users'
      ### Get matching property count
      get  'properties/matching/count',              to: 'property_search#matching_property_count'


      ### verify info about the properties which invited the vendor who is registering to verify
      get 'properties/details/:property_id',         to: 'property_search#details'

      ### Predict the locations and tag those locations with their type
      get 'locations/predict',                       to: 'locations_search#predict'
    end
  end
  post 'buyers/new/search',                       to: 'property_users/searches#new_saved_search'
  post 'buyers/override/search',                  to: 'property_users/searches#override_saved_searches'
  get  'buyers/searches',                         to: 'property_users/searches#saved_searches'
  get  'buyers/shortlist',                        to: 'property_users/searches#shortlisted_udprns'
  post 'buyers/new/shortlist',                    to: 'property_users/searches#new_shortlist'
  post 'buyers/delete/shortlist',                 to: 'property_users/searches#delete_shortlist'
  get  'buyers/callbacks',                        to: 'property_users/searches#callbacks'
  post 'buyers/new/callbacks',                    to: 'property_users/searches#new_callbacks'
  get  'buyers/viewings',                         to: 'property_users/searches#viewings'
  post 'buyers/new/viewings',                     to: 'property_users/searches#new_viewings'
  get  'buyers/offers',                           to: 'property_users/searches#offers'
  post 'buyers/new/offers',                       to: 'property_users/searches#new_offers'
  get  'buyers/messages',                         to: 'property_users/searches#messages'
  post 'buyers/new/message',                      to: 'property_users/searches#new_message'
  get  'buyers/matrix/searches',                  to: 'property_users/searches#matrix_searches'
  post 'buyers/new/matrix/search',                to: 'property_users/searches#new_matrix_search'
  resources :charges

  ### Facebook login routes
  get 'auth/:provider/callback',                  to: 'sessions#create'
  get 'signout',                                  to: 'sessions#destroy', as: 'signout'
  resources 'sessions',                           only: [:create, :destroy]
end
