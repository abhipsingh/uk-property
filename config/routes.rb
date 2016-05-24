Rails.application.routes.draw do
  devise_for :property_users,
             path_names: { sign_in: 'login', sign_out: 'logout', password: 'secret', confirmation: 'verification',
                           unlock: 'unblock', sign_up: 'register' },
             :controllers => { :omniauth_callbacks => 'property_users/omniauth_callbacks', registrations: 'property_users/registrations'}

  get 'welcome/index'
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'welcome#index'

  get '/auth/:provider/callback', to: 'sessions#create'
  get 'properties/new/short', to: 'properties#short_form'
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
      post 'buyers/new/search',                      to: 'property_search#save_searches'
      get  'buyers/searches',                        to: 'property_search#show_save_searches'
    end
  end
  resources :charges
end
