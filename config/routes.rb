Rails.application.routes.draw do
  devise_for :property_users,
             path_names: { sign_in: 'login', sign_out: 'logout', password: 'secret', confirmation: 'verification',
                           unlock: 'unblock', sign_up: 'register' },
             controllers: { omniauth_callbacks: 'property_users/omniauth_callbacks', registrations: 'property_users/registrations', confirmations: 'confirmations' }

  get 'welcome/index'
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'welcome#index'

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
  #####################################################################
  #####################################################################
  #####################################################################
  ###### QUOTES #######################################################
  #####################################################################
  #####################################################################
  #####################################################################
  ### Post events to the server
  post 'quotes/new',                         to: 'quotes#new'

  get 'quotes/submit',                       to: 'quotes#submit'
  #####################################################################
  #####################################################################
  #####################################################################

  ########### Routes for the vendors enquiries and buyer interest and other
  ##### sections
  #####################################################################
  #####################################################################
  
  ### For an agent get all his detailed quotes for a specific property
  get 'agents/quotes/:agent_id',            to: 'agents#quotes_per_property'

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
  #####################################################################
  #####################################################################
  
  get '/auth/:provider/callback', to: 'sessions#create'
  get 'properties/new/:udprn/short', to: 'properties#short_form'
  get 'postcodes/search', to: 'application#search_postcode'
  get 'addresses/search', to: 'application#search_address'
  get 'properties/:udprn/edit', to: 'properties#edit'
  get 'crawled_properties/:id/show', to: 'crawled_properties#show'
  get 'crawled_properties/search', to: 'crawled_properties#search'
  get 'crawled_properties/search_results', to: 'crawled_properties#search_results'
  get 'addresses/matrix_view', to: 'application#matrix_view'
  get 'addresses/predictions', to: 'application#predictive_search'
  get 'addresses/predictions/results', to: 'application#get_results_from_hashes'
  post 'addresses/follow', to: 'application#follow'
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
end
