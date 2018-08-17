Rails.application.routes.draw do
  namespace :vendors do

    ### Shows availability of the vendor
    get 'availability',                      to: :show_vendor_availability

    ### Add unavailablity slot for the vendor
    post 'add/unavailability',               to: :add_unavailable_slot

  end
end
