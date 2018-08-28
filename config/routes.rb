require 'sidekiq/web'

Rails.application.routes.draw do
  ### Pg hero route
  mount PgHero::Engine, at: "pghero"

  ### Sidekiq
  mount Sidekiq::Web => '/sidekiq'

  ### Post the list of invited friends and family(for a buyer/vendor)
  post 'properties/invite/friends/family',    to: 'properties#invite_friends_and_family'

  get 'welcome/index'
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'welcome#index'

  ### Test view
  get 'agents/test/view',                    to: 'buyers#test_view'

  ## JWT based authentication
  post 'authenticate', to: 'authentication#authenticate'

  ## Get user details
  get 'users/details', to: 'users#details'
  get 'users/postcode_area_panel_details',   to: 'users#postcode_area_panel_details'

  ###### ENQUIRIES ####################################################
  #####################################################################
  #####################################################################
  #####################################################################
  ### Gets property details for the vanity url
  get 'property/details/:vanity_url',        to: 'properties#details_from_vanity_url'

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
  get 'agents/properties/recent/quotes',     to: 'quotes#agents_recent_properties_for_quotes'

  ### Get all recently changed to Green properties for quotes for Agents
  get 'agents/properties/recent/claims',     to: 'leads#agents_recent_properties_for_claim'

  ### Get all stats about the properties for the concerned agents
  get 'agents/enquiries/properties',         to: 'events#property_enquiries'

  ### Get all properties quicklinks for the queried agent_id, or branch or group or company id
  get 'agents/quicklinks/properties',        to: 'events#quicklinks'

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
  #### Shows details of a specific property owned by a vendor
  get 'vendors/properties/details/:vendor_id',                  to: 'vendors#property_details'

  #### Edit vendor details 
  post 'vendors/:id/edit',                                      to: 'vendors#edit'

  #### Edit agent quotes
  post 'quotes/edit',                                           to: 'quotes#edit_agent_quote'

  #### Shows all the properties owned by a vendor
  get 'vendors/properties/:vendor_id',                          to: 'vendors#properties'

  #### Gets all the properties speicific to a postcode or building attributes
  get 'properties/search/claim',                                to: 'properties#properties_for_claiming'

  #### Edit basic details of a property
  post 'properties/claim/basic/:udprn/edit',                    to: 'properties#edit_basic_details'

  #### Update basic details of a property by a vendor
  post 'properties/vendor/basic/:udprn/update',                 to: 'properties#update_basic_details_by_vendor'

  #### Edit basic details of a buyer
  post 'buyers/:id/edit',                                       to: 'buyers#edit_basic_details'

  ### Details for a vendor when a token is provided
  post 'buyers/:id/edit',                                       to: 'property_buyers#edit'

  ### Get a presigned url for every image to be uploaded on S3
  get 's3/upload/url',                                          to: 's3#presigned_url'

  ### Verify that a upload happened
  get 's3/verify/upload',                                       to: 's3#verify_upload'

  ### For any vendor, claim an unknown udprn
  post 'properties/udprns/claim/:udprn',                        to: 'properties#claim_udprn'

  ### Verify property details, agent_id from the vendor
  post 'vendors/:udprn/verify/',                                to: 'vendors#verify_property_from_vendor'

  ### Verify the details submiitted by the agent and approve the agent as assigned_agent
  get 'vendors/:udprn/:agent_id/lead/details/verify/:verified', to: 'vendors#verify_details_submitted_from_agent_following_lead'

  #### Update basic details of a property by a vendor
  post 'properties/vendor/basic/:udprn/update',                 to: 'properties#update_basic_details_by_vendor'

  #### Gives predictions for buyer's name/mobile or email
  get 'buyers/predict',                                         to: 'buyers#predictions'

  ### Verify property as green and verified and the agent as assigned agent
  # post 'vendors/udprns/:udprn/agents/:agent_id/verify',         to: 'agents#verify_property_from_agent'

  ### Quote details api
  get '/property/quotes/details/:id',                           to: 'quotes#quote_details'

  ### Vendor Quote details api
  get '/quotes/property/:udprn',                                to: 'quotes#property_quote'
  
  ### Branches list for a district
  get '/branches/list/:location',                               to: 'agents#branch_info_for_location'

  ### matrix view searches testing perfect/potential
  get '/matrix/view/load/testing',                              to: 'matrix_view#matrix_view_load_testing'

  ### buyer tracking history
  get '/buyers/tracking/history',                               to: 'buyers#tracking_history'

  ### buyers premium access
  post '/buyers/premium/access',                                to: 'buyers#process_premium_payment'

  ### buyers tracking stats
  get '/buyers/tracking/stats',                                 to: 'buyers#tracking_stats'

  ### buyers tracking property details
  get '/buyers/tracking/details',                               to: 'buyers#tracking_details'

  ### populate lead visit time by the agent
  post '/agents/lead/submit/visit/time',                        to: 'leads#submit_lead_visit_time'

  ### Get pricing history for a property
  get '/property/pricing/history/:udprn',                       to: 'properties#pricing_history'

  ### Count of matching properties(aggregate) not divided by property_status_type
  post '/buyers/tracking/remove/:tracking_id',                  to: 'buyers#edit_tracking'

  ### Get pricing history for a property
  get '/property/pricing/history/:udprn',                       to: 'properties#pricing_history'

  ### Count of matching properties(aggregate) not divided by property_status_type
  get '/property/aggregate/supply/:udprn',                      to: 'properties#supply_info_aggregate'

  ### For vendors, get the details of the quote
  get '/property/quotes/property/:udprn',                       to: 'quotes#property_quote'

  ### Attach the vendor to a manually added property(No basic attributes though)
  post 'properties/manually/added/claim/vendor',                to: 'properties#attach_vendor_to_udprn_manual_for_manually_added_properties'

  ### Auto suggest new properties
  get 'properties/new/suggest',                                 to: 'auto_suggests#suggest_new_properties'

  ### Get unclaimed properties for udprn
  get '/properties/unclaimed/search/:postcode',                 to: 'properties#unclaimed_properties_for_postcode'

  ### Quotes history for agents
  get 'quotes/agents/history',                                  to: 'quotes#historical_agent_quotes'

  ### Vendor quotes history
  get 'quotes/vendors/history/:udprn',                          to: 'quotes#historical_vendor_quotes'

  ### Claim a property for renter
  post 'property/claim/renter',                                 to: 'properties#upload_property_details_from_a_renter'

  ### Get tags(field values) for a field
  get 'tags/:field',                                            to: 'properties#show_tags'

  ### Add new tags(field values) for a field
  post 'tags/:field',                                           to: 'properties#add_new_tags'

  ### Predict tags for a particular field
  get 'predict/tags',                                           to: 'properties#predict_tags'

  ### Invite a friend/family to a property
  post 'invite/friends/family/',                                to: 'properties#invite_friends_and_family'

  ### Level specific matrix view search
  get 'matrix/view/level',                                      to: 'matrix_view#matrix_view_level'

  ### Process premium subscription for users through Stripe
  post '/users/subscribe/premium/service',                      to: 'buyers#subscribe_premium_service'

  ### Info about the premium charges monthly
  get '/users/premium/cost',                                    to: 'buyers#info_premium'

  ### Remove user subscription
  post '/agents/premium/subscription/remove',                   to: 'buyers#remove_subscription'

  ### Provide matching udprns for a crawled property id
  get 'agents/matching/udprns/property/:property_id',           to: 'agents#matching_udprns'

  ### Get the list of properties the agent has been attached to
  get '/agents/list/properties',                                to: 'agents#list_of_properties'

  ### Get buyer stats for enquiry
  get '/agents/buyer/enquiry/stats/:enquiry_id',                to: 'events#buyer_stats_for_enquiry'

  ### Get the top level stats for a vendor/agent for a property
  get '/property/stats/:udprn',                                 to: 'properties#property_stats'

  ### Unverify the agent's property by a invited vendor for a property
  post 'vendors/unverify/:udprn/:agent_id',                     to: 'vendors#unverify_agent_from_a_property'

  ### Get a list of vendors invited by agents as f&f
  get '/vendors/verify/inviting/agents',                        to: 'vendors#list_inviting_agent_and_property'

  get 'non/crawled/properties',                                 to: 'vendors#non_crawled_properties'

  post 'non/properties',                                        to: 'vendors#post_non_crawled_properties'

  ### Edit basic details of a property claimed by a vendor having an assigned agent already
  post 'properties/claim/assigned/basic/:udprn/edit',           to: 'properties#edit_basic_details_with_an_assigned_agent'

  ### For vendors invited through both the sources, get agent details
  get 'property/vendor/agent/details/verify/:udprn',            to: 'properties#agent_details_for_the_vendor'

  ### Fetch the list of invited friends and family(for a buyer/vendor)
  get 'list/invite/friends/family',                             to: 'properties#invited_f_and_f_list'

  ### List of properties for the vendor and the agent confirmation status
  get 'list/inviting/agents/properties',                        to: 'vendors#list_inviting_agents_properties'

  ### Returns whether a property has been preempted by the agent or not
  get 'property/:udprn/preemption/status',                      to: 'properties#preemption_status'

  ### Autosuggest for france
  get 'addresses/predictions/fr',                               to: 'matrix_view#fr_predictive_search'

  get 'fetch/available/url/fr',                                 to: 'properties#fetch_available_url'

  post 'process/url/fr',                                        to: 'properties#process_url'

  ### Unique buyer count for property's enquiries
  get 'enquiries/unique/buyer/count/:udprn',                    to: 'events#unique_buyer_count'



  #####################################################################
  #####################################################################
  #####################################################################
  #####################################################################
  #####################################################################
  
  post '/auth/:provider/callback', to: 'sessions#create'
  get 'postcodes/search', to: 'matrix_view#search_postcode'
  get 'addresses/search', to: 'matrix_view#search_address'
  get 'properties/:udprn/edit', to: 'properties#edit'
  get 'crawled_properties/:id/show', to: 'crawled_properties#show'
  get 'crawled_properties/search', to: 'crawled_properties#search'
  get 'crawled_properties/search_results', to: 'crawled_properties#search_results'
  get 'addresses/matrix_view', to: 'matrix_view#matrix_view'
  get 'addresses/predictions', to: 'matrix_view#predictive_search'
  namespace :api do
    namespace :v0 do
      ### Get breadcrumbs for a hash and a type
      get  'properties/breadcrumbs',                 to: 'property_search#breadcrumbs'

      get  'properties/search',                      to: 'property_search#search'
      get  'properties/fr/search',                   to: 'property_search#search_fr'
      get  'properties/saved/searches',              to: 'property_search#show_save_searches'
      post  'properties/search/searches',            to: 'property_search#save_searches'
      get  'agents/search',                          to: 'agent_search#search'
      get  'ads/availability',                       to: 'vendor_ad#ads_availablity'
      post 'ads/availability/update',                to: 'vendor_ad#update_availability'

      ### Get matching property count
      get  'properties/matching/count',              to: 'property_search#matching_property_count'

      ### verify info about the properties which invited the vendor who is registering to verify
      get 'properties/details/:property_id',         to: 'property_search#details'

      ### Predict the locations and tag those locations with their type
      get 'locations/predict',                       to: 'locations_search#predict'
    
      ### Returns street and locality hash for any given udprn
      get 'property/hash/:udprn',                    to: 'property_search#udprn_street_locality_hash'

      ### Randomise property ads
      get 'randomise/ads/property',                  to: 'property_search#randomise_property_ad'

    end
  end

end

