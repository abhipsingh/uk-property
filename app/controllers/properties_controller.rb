class PropertiesController < ActionController::Base
  include CacheHelper
  #### Edit property url
  #### curl -XPOST -H "Content-Type: application/json"  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/properties/10966139/edit/details' -d '{ "details" : { "property_type" : "Terraced House", "beds" : 3, "baths" : 2, "receptions" : 2, "property_status_type" : "Green", "property_style" : "Period", "tenure" : "Freehold", "floors" : 2, "listed_status" : "Grade 1", "year_built" : "2011-01-01", "central_heating" : "Partial", "parking_type" : "Single garage", "outside_space_type" : "Private garden", "additional_features" : ["Attractive views", "Fireplace"], "decorative_condition" : "Newly refurbished", "council_tax_band" : "A", "lighting_cost" : 120, "lighting_cost_unit_type" : "month", "heating_cost": 100, "heating_cost_unit_type" : "month", "hot_water_cost" : 200, "hot_water_cost_unit_type" : "month", "annual_ground_water_cost" : 1100, "annual_service_charge" : 200, "resident_parking_cost" : 1200, "other_costs" : [{ "name" : "Cost 1", "value" : 200, "unit_type" : "month" } ], "improvement_types" : [ { "name" : "Total refurbishment", "value" : 200, "date": "2016-06-01" }  ], "current_valuation" : 32000, "dream_price" : 42000, "rental_price" : 1000, "floorplan_url" : "some random url", "pictures" : [{"category" : "Front", "url" : "random url" }, { "category" : "Garden", "url" : "Some random url" } ], "property_brochure_url" : "some random url", "video_walkthrough_url" : "some random url", "property_sold_status" : "Under offer", "agreed_sale_value" : 37000, "expected_completion_date" : "2017-03-13", "actual_completion_date" : "2017-04-01", "new_owner_email_id" : "a@b.com" , "vendor_address" : "Some address" } }'
  #### TODO: Validations
  def edit_property_details
    if user_valid_for_viewing?(['Agent', 'Vendor'], params[:udprn].to_i)
      udprn = params[:udprn].to_i
      details = params[:details]
      updated_details = PropertyService.new(udprn).edit_details(details, @current_user)
      render json: { message: 'Property details edited', response: details }, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### When a request is made to fetch the historic pricing details for a udprn
  ### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/prices/10966139'
  def historic_pricing
      details = PropertyDetails.historic_pricing_details(params[:udprn].to_i)
      render json: details, status: 200
  end

  ### This route provides all the details of the recent enquiries made by the users on this property
  ### curl -XGET -H "Content-Type: application/json"  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/enquiries/property/10966139'
  def enquiries
    if user_valid_for_viewing?(['Agent', 'Vendor'], params[:udprn].to_i)
      cache_response(params[:udprn].to_i, []) do
        enquiries = Trackers::Buyer.new.property_enquiries(params[:udprn].to_i)
        render json: enquiries, status: 200
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  #### The following actions are specific for data related to buyer interest tables and pie charts
  #### From interest awareness table, this action gives the data regarding buyer activity related to
  #### the property.
  #### curl -XGET -H "Content-Type: application/json"  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/property/interest/10966139'
  def interest_info
    if user_valid_for_viewing?(['Agent', 'Vendor'], params[:udprn].to_i)
      cache_response(params[:udprn].to_i, []) do
        interest_info = Trackers::Buyer.new.interest_info(params[:udprn].to_i)
        render json: interest_info, status: 200
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  #### From supply table, this action gives the data regarding how many properties are similar to
  #### their property.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/supply/10966139'
  def supply_info
    supply_info = Trackers::Buyer.new.supply_info(params[:udprn].to_i)
    render json: supply_info, status: 200
  end

  #### From supply table, this action gives the data regarding how many buyers are searching for properties
  #### similar to their property.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/demand/10966139'
  def demand_info
    demand_info = Trackers::Buyer.new.demand_info(params[:udprn].to_i)
    render json: demand_info, status: 200
  end

  #### From supply table, this action gives the data regarding how many buyers are searching for properties
  #### similar to their property.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/buyer/intent/10966139'
  def buyer_intent_info
    buyer_intent_info = Trackers::Buyer.new.buyer_intent_info(params[:udprn].to_i)
    render json: buyer_intent_info, status: 200
  end

  #### For all the pie charts concerning the profile of the buyer, this action can be used.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/buyer/profile/stats/10966139'
  def buyer_profile_stats
    buyer_profile_stats = Trackers::Buyer.new.buyer_profile_stats(params[:udprn].to_i)
    render json: buyer_profile_stats, status: 200
  end

  #### For all the pie charts concerning the profile of the buyer, this action can be used.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/agent/stage/rating/stats/10966139?agent_id=1234'
  def agent_stage_and_rating_stats
    agent_id = PropertyDetails.details(params[:udprn].to_i)['_source']['agent_id'] rescue nil
    if agent_id ### && quote.status == 1
      response = Trackers::Buyer.new.agent_stage_and_rating_stats(params[:udprn].to_i)
      status = 200
    else
      response = { message: " You're not subscribed to this property " }
      status = 400
    end
    render json: response, status: status
  end

  #### Ranking stats for the given property
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/ranking/stats/10966139'
  def ranking_stats
    ranking_info = Trackers::Buyer.new.ranking_stats(params[:udprn].to_i)
    render json: ranking_info, status: status
  end

  #### Ranking stats for the given property
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1'
  #### Four filters can be applied
  #### type_of_enquiry
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1?enquiry_type=requested_message'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1?type_of_match=Perfect'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1?property_status_type=Green'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1?search_str=Jacqueline'
  def history_enquiries
    enquiry_type = params[:enquiry_type]
    type_of_match = params[:type_of_match].downcase.to_sym if params[:type_of_match]
    property_status_type = params[:property_status_type]
    search_str = params[:search_str]
    property_for = params[:property_for]
    property_for ||= 'Sale'
    property_for = 'Rent' if property_for != 'Sale'
    cache_parameters = [ :enquiry_type, :type_of_match, :property_status_type,:search_str, :property_for].map{ |t| params[t].to_s }
    cache_response(params[:buyer_id].to_i, cache_parameters) do
      ranking_info = Trackers::Buyer.new.history_enquiries(params[:buyer_id].to_i, enquiry_type, type_of_match, property_status_type, search_str, property_for)
      render json: ranking_info, status: status
    end
  end

  #### Gets the properties which satisfy the postcode, or the building name filter
  ### curl -XGET -H "Content-Type: application/json" 'http://localhost/properties/search/claim?str=25'
  def properties_for_claiming
    search_str = params[:str]
    postcode = params[:postcode]
    search_hash = {}
    search_hash[:postcode] = params[:postcode] if params[:postcode] && !params[:postcode].empty?
    search_hash[:sub_building_name] = params[:str] if params[:str] && !params[:str].empty?
    search_hash[:building_name] = params[:str] if params[:str] && !params[:str].empty?
    search_hash[:building_number] = params[:str] if params[:str] && !params[:str].empty?
    search_hash[:postcode] = params[:str] if params[:str] && !params[:str].empty?
    api = PropertySearchApi.new(filtered_params: search_hash )
    api.apply_filters
    api.add_not_exists_filter('vendor_id')
    api.make_or_filters([:sub_building_name, :building_name, :building_number, :postcode])
    body, status = api.fetch_data_from_es
    render json: body, status: status
  end

  ### Edit basic details of a property
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/properties/claim/basic/10966139/edit' -d '{ "beds" : 2, "baths": 190, "receptions" : 34, "property_status_type" : "Green", "dream_price" : 34000 }'
  def edit_basic_details
    udprn = params[:udprn].to_i
    client = Elasticsearch::Client.new(host: Rails.configuration.remote_es_host)
    body = {}
    body[:dream_price] = params[:dream_price].to_i
    body[:beds] = params[:beds].to_i
    body[:baths] = params[:baths].to_i
    body[:receptions] = params[:receptions].to_i
    body[:property_status_type] = params[:property_status_type] if params[:property_status_type]
    body[:verification_status] = false
    PropertyDetails.update_details(client, udprn, body)
    render json: { message: 'Successfully updated' }, status: 200
  rescue Exception => e
    render json: { message: 'Update failed' }, status: 400
  end

  #### When a vendor click the claim to a property, the vendor gets a chance to visit
  #### the picture. The claim needs to be frozen and the property is no longer available
  #### for claiming.
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/properties/udprns/claim/4745413' -d '{ "vendor_id" : 1235, "property_for" : "Sale" }'
  def claim_udprn
    udprn = params[:udprn].to_i
    vendor_id = params[:vendor_id]
    params[:property_for] != 'Sale' ? params[:property_for] = 'Rent' : params[:property_for] = 'Sale'
    property_service = PropertyService.new(udprn)
    property_service.attach_vendor_to_property(vendor_id, {}, params[:property_for])
    render json: { message: 'You have claimed this property Successfully. All the agents in this district will be notified' }, status: 200
  rescue ActiveRecord::RecordNotUnique
    render json: { message: 'Sorry, this udprn has already been claimed' }, status: 400
  rescue Exception
    render json: { message: 'Sorry, this udprn has already been claimed' }, status: 400
  end

  ### Update basic details of a property by a vendor. Part of vendor verification workflow process
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/properties/vendor/basic/10966139/update' -d '{ "beds" : 2, "baths": 190, "receptions" : 34, "property_status_type" : "Green", "vendor_id" : 1, "property_type": "Countryside" }'
  def update_basic_details_by_vendor
    update_basic_details_by_vendor_params
    udprn = params[:udprn].to_i
    client = Elasticsearch::Client.new(host: Rails.configuration.remote_es_host)
    body = {}
    vendor_id = params[:vendor_id].to_i
    body[:vendor_id] = vendor_id
    body[:beds] = params[:beds].to_i
    body[:baths] = params[:baths].to_i
    body[:receptions] = params[:receptions].to_i
    body[:property_status_type] = params[:property_status_type] if params[:property_status_type]
    body[:property_type] = params[:property_type]
    body[:verification_status] = false
    property_service = PropertyService.new(udprn)
    property_service.attach_vendor_to_property(vendor_id, body)
    PropertyDetails.update_details(client, udprn, body)
    render json: { message: 'Successfully updated' }, status: 200
  rescue Exception => e
    render json: { message: "Update failed  #{e}" }, status: 400
  end

  ### Auxilliary action used for testing purposes
  def process_event
    event_controller = EventsController.new
    event_controller.request = request
    event_controller.response = response
    event_controller.process_event
    render json: { response: response.body }, status: 200
  end

  private

  def short_form_params
    params.permit(:agent, :branch, :property_status, :receptions, :beds, :baths, :property_type, :dream_price, :udprn)
  end

  def user_valid_for_viewing?(user_types, udprn)
    user_types.any? do |user_type|
      @current_user = authenticate_request(user_type).result
      !@current_user.nil?
    end
  end

  def authenticate_request(klass='Agent')
    AuthorizeApiRequest.call(request.headers, klass)
  end

  def update_basic_details_by_vendor_params
    params.require(:vendor_id)
    params.require(:beds)
    params.require(:baths)
    params.require(:receptions)
    params.require(:property_status_type)
    params.require(:property_type)
  end


end
