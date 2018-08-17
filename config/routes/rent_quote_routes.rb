Rails.application.routes.draw do
  namespace 'rent' do
    get '/property/quotes/agents/:udprn',                                  to: 'quotes#quotes_per_property'

    post '/quotes/property/:udprn',                                        to: 'quotes#new_quote_for_property'

    post '/quotes/new',                                                    to: 'quotes#new'

    post '/quotes/edit/',                                                  to: 'quotes#edit_agent_quote'

    post '/quotes/submit/:quote_id',                                       to: 'quotes#submit'

    get '/property/quotes/details/:id',                                    to: 'quotes#quote_details'

    get '/property/quotes/property/:udprn',                                to: 'quotes#property_quote'

    get '/agents/properties/recent/quotes',                                to: 'quotes#agents_recent_properties_for_quotes'
  end
end

