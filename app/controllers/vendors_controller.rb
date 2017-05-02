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

  ### Quicklinks of the properties that the vendor holds
  # curl -XGET -H "Content-Type: application/json" 'http://localhost/vendors/properties/:vendor_id'
  # curl -XGET -H "Content-Type: application/json" 'http://localhost/vendors/properties/1'
  def properties
    # vendor = Vendor.find(params[:vendor_id])
    pd = PropertySearchApi.new(filtered_params: { vendor_id: params[:vendor_id].to_i } )
    results, status = pd.filter
    results[:results].each { |e| e[:address] = PropertyDetails.address(e) }
    response = results[:results].map { |e| e.slice('udprn', :address)  }
    render json: response, status: status
  end

  ### Details of a specific property that a vendor holds
  ### curl -XGET -H "Content-Type: application/json" 'http://localhost/vendors/properties/details/1?udprn=10966139'
  def property_details
    details = VendorApi.new(params[:udprn].to_i, nil, params[:vendor_id].to_i).property_details
    render json: details, status: 200
  end

  ### Edit vendor details
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost/vendors/86/edit' -d '{ "vendor" : { "name" : "Jackie Chan", "email" : "jackie.bing@friends.com", "mobile" : "9873628232", "password" : "1234567890", "image_url": "some_random_url" } }'
  def edit
    vendor_params = params[:vendor]
    vendor = Vendor.where(id: params[:id].to_i).first
    if vendor
      vendor.name = vendor_params[:name] if vendor_params[:name]
      vendor.mobile = vendor_params[:mobile] if vendor_params[:mobile]
      vendor.password = vendor_params[:password] if vendor_params[:password]
      vendor.image_url = vendor_params[:image_url] if vendor_params[:image_url]
      if vendor.save
        render json: { message: 'Vendor successfully updated', details:  vendor.as_json }, status: 200
      else
        render json: { message: 'Vendor not able to update' }, status: 400
      end
    else
      render json: { message: 'Vendor not found' }, status: 404
    end
  end
end


