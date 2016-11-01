class VendorsController < ApplicationController
  def valuations
    property_id = params[:udprn]
    vendor_api = VendorApi.new(property_id)
    vendor_api.calculate_valuations
    render json: valuation_info
  end


  ##### To emulate this we need some sold properties of agents and some changes
  ##### to the valuations in those sold properties. To have those, we can issue
  ##### the following curl requests

  ##### Three udprns have been marked to be shown as sold
  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "sold", "message" : "\{ \"final_price\" : 300000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10977419', "event" : "sold", "message" : "\{ \"final_price\" : 340000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  #  curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '54042234', "event" : "sold", "message" : "\{ \"final_price\" : 360000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  #### For each of the udprn [10976765, 10977419, 54042234] events concerning valuation change are selected
  # ######## For 10976765
  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 280000, \"current_valuation\" : 285000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 285000, \"current_valuation\" : 289000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 289000, \"current_valuation\" : 295000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 295000, \"current_valuation\" : 300000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # ######## For 10977419
  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10977419', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 335000, \"current_valuation\" : 320000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10977419', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 320000, \"current_valuation\" : 318000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10977419', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 318000, \"current_valuation\" : 340000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # ####### For 54042234

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '54042234', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 350000, \"current_valuation\" : 340000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '54042234', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 340000, \"current_valuation\" : 360000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'


  def quotes
    property_id = params[:udprn]
    vendor_api = VendorApi.new(property_id)
    quotes = vendor_api.calculate_quotes(branch_ids.split(',').map(&:to_i))
    render json: quotes
  end
end