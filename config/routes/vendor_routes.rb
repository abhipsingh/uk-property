Rails.application.routes.draw do
  namespace :vendors do

    ### Shows availability of the vendor
    get 'availability',                      action: :show_vendor_availability

    ### Add unavailablity slot for the vendor
    post 'add/unavailability',               action: :add_unavailable_slot

  end
end
