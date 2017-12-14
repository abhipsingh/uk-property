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
    search_params = { vendor_id: params[:vendor_id].to_i, results_per_page: 150 }
    search_params[:p] = params[:p].to_i if params[:p]
    pd = PropertySearchApi.new(filtered_params: search_params )
    pd.query[:size] = 1000
    results, status = pd.filter
    results[:results].each { |e| e[:address] = PropertyDetails.address(e) }
    response = results[:results].map { |e| e.slice(:udprn, :address)  }
    response = response.sort_by{ |t| t[:address] }
    #Rails.logger.info "sending response for vendor properties -> #{response.inspect}"
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
      vendor.first_name = vendor_params[:first_name] if vendor_params[:first_name]
      vendor.last_name = vendor_params[:last_name] if vendor_params[:last_name]
      vendor.name = vendor_params[:first_name] + vendor_params[:last_name] if vendor_params[:first_name] && params[:last_name]
      vendor.mobile = vendor_params[:mobile] if vendor_params[:mobile]
      vendor.password = vendor_params[:password] if vendor_params[:password]
      vendor.image_url = vendor_params[:image_url] if vendor_params[:image_url]
      update_hash = { vendor_id: params[:id].to_i }
      ### TODO: Update attributes in all the properties
      if vendor.save
        VendorUpdateWorker.new.perform(vendor.id)
        render json: { message: 'Vendor successfully updated', details:  vendor.as_json }, status: 200
      else
        render json: { message: 'Vendor not able to update' }, status: 400
      end
    else
      render json: { message: 'Vendor not found' }, status: 404
    end
  end
  
  ### After the agent who won the lead, surveyed the property, submitted the property details
  ### and the email which was consequently sent to the vendor. This is the api called by the email
  ### link to judge the vendor's response as affirmative or negative
  ### curl  -XGET -H "Authorization: Random header" 'http://localhost/vendors/:udprn/:agent_id/lead/details/verify/:verified'
  ### curl  -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxMjM0LCJleHAiOjE0OTY2NzAwNzV9.QZKmD9Jrt_TuJH9JvA-QTr5xY77tNdDt6bF2vzK8kW0"  'http://localhost/vendors/12843737/1234/lead/details/verify/true'
  def verify_details_submitted_from_agent_following_lead
    if user_valid_for_viewing?(['Vendor'], params[:udprn].to_i)
      verified = params[:verified] == 'true' ? true : false
      vendor_id = @current_user.id
      agent_id = params[:agent_id].to_i
      if verified
        PropertyService.new(params[:udprn].to_i).attach_assigned_agent(agent_id)
        render json: { message: 'The agent has been chosen as your assigned agent' }, status: 200
      else
        ### TODO: Report to the admin
        render json: { message: 'The incident will reported to admin' }, status: 400
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  private

  def user_valid_for_viewing?(user_types, udprn)
    user_types.any? do |user_type|
      @current_user = authenticate_request(user_type).result
      !@current_user.nil?
    end
  end

  def authenticate_request(klass='Agent')
    AuthorizeApiRequest.call(request.headers, klass)
  end
end

