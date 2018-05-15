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
  get 'agents/properties',                                      to: 'agents#detailed_properties'

  #### For an agent, claim this property
  post 'events/property/claim/:udprn',                          to: 'agents#claim_property'

  ### For the agent, when he authorizes also make him attach his properties to the udprn
  get 'agents/:id/udprns/attach/verify',                        to: 'agents#verify_udprn_to_crawled_property'

  ### Get additional details of an agent related to invited agents count and friends and family count
  get 'agents/additional/details',                              to: 'agents#additional_agent_details_intercom'

  ### Agent credit info
  get 'agents/credit/info',                                     to: 'agents#agent_credit_info'

  ### Verify property attrs for non f and f vendors
  post 'agents/properties/:udprn/manual/verify/non/fandf',      to: 'agents#verify_manual_property_from_agent_non_f_and_f'

  ### Fetch agent details for a vanity url
  get 'agents/details/:vanity_url',                             to: 'agents#agent_vanity_url_details'

  ### Fetch branch details for a vanity url
  get 'branches/details/:vanity_url',                           to: 'agents#branch_vanity_url_details'

  ### Fetch company details for a vanity url
  get 'companies/details/:vanity_url',                          to: 'agents#company_vanity_url_details'

  ### Fetch group details for a vanity url
  get 'groups/details/:vanity_url',                             to: 'agents#group_vanity_url_details'

  ### Get the list of properties with incomplete details
  get 'agents/list/incomplete/properties',                      to: 'agents#incomplete_list_of_properties'

  ### Verify agent for a vendor
  post 'vendors/udprns/:udprn/agents/:agent_id/verify',         to: 'agents#verify_agent'

  ### Unlock the agents by making a stripe payment
  post 'unlock/agents',                                         to: 'agents#unlock_agent'

  ### Send emails to all buyers who produced enquiries for a property(archived/non archived
  post 'agents/properties/send/emails/enquiries',               to: 'agents#send_emails_to_enquiry_producing_buyers'

  ### Send emails to all buyer emails which made enquiries for this property
  get 'agents/enquiry/count/emails/:udprn',                     to: 'agents#enquiry_count_for_buyer_emails'

  ### Send emails to all buyer emails
  get 'agents/bulk/send/buyers/emails',                         to: 'agents#send_bulk_emails_to_buyers'

end

