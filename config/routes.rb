Rails.application.routes.draw do
  get '/auth/:provider/callback', to: 'sessions#create'
  get 'postcodes/search', to: 'application#search_postcode'
  get 'addresses/search', to: 'application#search_address'
  get 'properties/:udprn/edit', to: 'properties#edit'
  get 'addresses/matrix_view', to: 'application#matrix_view'
  get 'addresses/predictions', to: 'application#predictive_search'
  get 'addresses/predictions/results', to: 'application#get_results_from_hashes'
  namespace :api do
    namespace :v0 do
      get 'properties/search',        to: 'property_search#search'
      get 'ads/availability',         to: 'vendor_ad#ads_availablity'
      get 'locations/:id/version',    to: 'vendor_ad#correct_version'
      post 'ads/payments/new',        to: 'vendor_ad#new_payment'
      post 'ads/availability/update', to: 'vendor_ad#update_availability'
      post 'properties',              to: 'property_search#new_property'
    end
  end
  resources :charges
end
