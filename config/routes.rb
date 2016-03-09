Rails.application.routes.draw do
  get '/auth/:provider/callback', to: 'sessions#create'
  get 'postcodes/search', to: 'application#search_postcode'
  get 'addresses/search', to: 'application#search_address'
  get 'properties/:udprn/edit', to: 'properties#edit'
  namespace :api do
    namespace :v0 do
      get 'properties/search',        to: 'property_search#search'
      get 'ads/availability',         to: 'vendor_ad#ads_availablity'
      post 'ads/availability/update', to: 'vendor_ad#update_availability'
      post 'properties',              to: 'property_search#new_property'
    end
  end
end
