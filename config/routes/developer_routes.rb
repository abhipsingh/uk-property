Rails.application.routes.draw do

  #### Developer routes for search any of agent, group, branch or assigned agents by name
  get 'developers/predictions',                          to: 'developers#search'
  
  ### Get agent details for authentication token
  get '/details/developers',                             to: 'sessions#developer_details'

  ### Register a developer
  post '/register/developer/',                           to: 'sessions#create_developer'

  ### Login as a developer
  post '/login/developer/',                              to: 'sessions#login_developer'

  ### Searches for developers
  get '/agents/predictions',                             to: 'developers#search'

  ### Group by a district and calculate the number of agents and branches
  get '/developers/info/:udprn',                         to: 'developers#local_info'

  #### Information about developer branches for this district
  get '/developers/branches/list/:district',             to: 'developers#list_branches'

  ### Details of the developer
  get '/developers/employee/:developer_id',              to: 'developers#developer_details'

  ### Details of the branch
  get '/developers/branch/:branch_id',                   to: 'developers#branch_details'

  ### Details of the company
  get '/agents/company/:company_id',                     to: 'developers#company_details'

  ### Details of the group
  get '/developers/group/:group_id',                     to: 'developers#group_details'

  ### Add company, branch and group details to a developer
  post '/developers/register',                           to: 'developers#add_developer_details'

  #### Invite the other developers to register
  post '/developers/invite',                             to: 'developers#invite_developers_to_register'

  ### Shows the udprns in the branch_id which are not verified and Green along with 
  get '/developers/:id/udprns/verify',                   to: 'developers#verify_developer_udprns'

  ### Invite vendor to verify the udprn
  post '/developers/:developer_id/udprns/:udprn/verify', to: 'developers#invite_vendor_developer'

  ### Get the developer info who sent the mail to the vendor
  post '/vendors/invite/udprns/:udprn/developers/info',  to: 'developers#invite_vendor_developer'

  ### Get the developer info who sent the mail to the vendor
  get '/vendors/invite/udprns/:udprn/developers/info',   to: 'developers#info_for_developer_verification'

  ### Verify the developer as the intended developer and udprn as the correct udprn
  get '/vendors/udprns/:udprn/developers/23/verify',     to: 'developers#verify_developer_for_developer_claimed_property'

  #### Edit details of a branch
  post '/developers/branches/:branch_id/edit',           to: 'developers#edit_branch_details'

  ### Edit detals of a company
  post '/developers/companies/:company_id/edit',         to: 'developers#edit_company_details'

  ### Edit detals of a grpup
  post '/groups/:group_id/edit',                         to: 'developers#edit_group_details'

  ### Edit developer employee details of a developer employee
  post '/developers/employees/:developer_id/edit',       to: 'developers#edit_developer_details'

  ### Bulk upload developers properties
  post '/developers/properties/verify',                  to: 'developers#verify_properties_through_developer'

  ### History of properties which have been manually uploaded by the developers
  get '/developers/upload/history/properties',           to: 'developers#upload_property_history'

  ### List of all the invited developers for a developer branch
  get 'developers/list/invited/developers',              to: 'developers#branch_specific_invited_developers'

end

