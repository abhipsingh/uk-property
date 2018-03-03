Rails.application.routes.draw do
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

  ### Details for an agent when a token is provided
  get 'details/agents',                                         to: 'sessions#agent_details'

  ### Verify the udprns and invite the vendors
  get 'agents/:id/udprns/verify',                               to: 'agents#verify_udprns'

  ### Invite vendors by sending them an email
  post 'agents/:agent_id/udprns/:udprn/verify',                 to: 'agents#invite_vendor'

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

  ### get info about the agents which invited the vendor who is registering to verify and change password as well
  post 'vendors/invite/udprns/:udprn/agents/info',               to: 'agents#info_for_agent_verification'

  ### verify info about the agents which invited the vendor who is registering to verify
  post 'vendors/udprns/:udprn/agents/:agent_id/verify',         to: 'agents#verify_property_from_vendor'

  ### verify info about the properties which invited the vendor who is registering to verify
  post 'vendors/udprns/:udprn/verify',                          to: 'agents#verify_property_from_vendor'

  ### Update property details, attach udprn to crawled properties, send
  ### vendor email and add assigned agents to properties
  post 'agents/properties/:udprn/verify',                       to: 'agents#verify_property_through_agent'

  ### Update property details, attach udprn to manually added properties, send
  ### vendor email and add assigned agents to properties
  post 'agents/properties/:udprn/manual/verify',                to: 'agents#verify_manual_property_from_agent'

  ####  Creates a new agent with a randomized password
  post 'agents/add/:agent_id',                                  to: 'agents#create_agent_without_password'

  ####  Adds credits to agents
  post 'agents/credits/add',                                    to: 'agents#add_credits'

  ####  Adds credits to agents
  get 'agents/credits/history',                                 to: 'agents#credit_history'

  ### Webhook for stripe monthly agent premium service subscription
  post 'agents/premium/subscription/process',                   to: 'agents#process_subscription'

  ### Info about the premium cost
  get 'agents/premium/cost',                                    to: 'agents#info_premium'

  ### Info about the leads generated from manually claimed properties
  get 'agents/manual/properties/leads',                         to: 'agents#manual_property_leads'

  ### For agents subscribe to a premium service
  post '/agents/subscribe/premium/service',                     to: 'agents#subscribe_premium_service'

  ### For agents info about premium subscription
  get '/agents/premium/cost',                                   to: 'agents#info_premium'

  ### For agents callback api from stripe
  post '/agents/premium/subscription/process',                  to: 'agents#process_subscription'

  ### For agents Stripe agents subscription recurring payment 
  post '/agents/premium/subscription/remove',                   to: 'agents#remove_subscription'

  ### For agents, get the details of the crawled property
  get '/agents/details/property/:property_id',                  to: 'agents#crawled_property_details'

  ### Get all the details of an agent who invited the vendor via friends and family
  get 'properties/agent/details/:udprn',                        to: 'agents#manual_agent_details'

  ### History of manually claimed properties for an agent
  get 'agents/properties/history/invited',                      to: 'agents#invited_vendor_history'

  ### Filter claimed properties
  post '/properties/filter/claimed',                            to: 'agents#filter_claimed_udprns'

  ### Gets the list of invited agents for a branch
  get 'agents/list/invited/agents',                             to: 'agents#branch_specific_invited_agents'

  ### Properties for an agent which have missing sale price
  get '/agents/properties/quotes/missing/price',                to: 'agents#missing_sale_price_properties_for_agents'

  ### Credits chargeable info for an agent for an enquiry
  get '/agents/inactive/property/credits/:udprn',               to: 'agents#inactive_property_credits'

  ### Search for agents companies by name
  get 'agents/search/companies',                                to: 'agents#search_company'

  ### Get all properties quicklinks for the queried agent_id, or branch or group or company id
  get 'agents/properties',                   to: 'agents#detailed_properties'

  #### For an agent, claim this property
  post 'events/property/claim/:udprn',     to: 'agents#claim_property'

  ### For the agent, when he authorizes also make him attach his properties to the udprn
  get 'agents/:id/udprns/attach/verify',                        to: 'agents#verify_udprn_to_crawled_property'

  ### For all the users, to reset their password if they have done an email based signup
  post '/forgot/password',                                      to: 'sessions#forgot_password'

  ### Reset password for any user
  post '/reset/password',                                       to: 'sessions#reset_password'

  ### Sends an SMS to a mobile number to check it later
  post '/send/otp',                                             to: 'sessions#send_otp_to_number'

  ### Destroys a session
  get 'signout',                                                to: 'sessions#destroy',   as: 'signout'
end

