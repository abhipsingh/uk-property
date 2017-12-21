class PropertiesController < ActionController::Base

  include CacheHelper
  before_filter :set_headers

  #### Edit property url
  #### curl -XPOST -H "Content-Type: application/json"  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/properties/10966139/edit/details' -d '{ "details" : { "property_type" : "Terraced House", "beds" : 3, "baths" : 2, "receptions" : 2, "property_status_type" : "Green", "property_style" : "Period", "tenure" : "Freehold", "floors" : 2, "listed_status" : "Grade 1", "year_built" : "2011-01-01", "central_heating" : "Partial", "parking_type" : "Single garage", "outside_space_type" : "Private garden", "additional_features" : ["Attractive views", "Fireplace"], "decorative_condition" : "Newly refurbished", "council_tax_band" : "A", "lighting_cost" : 120, "lighting_cost_unit_type" : "month", "heating_cost": 100, "heating_cost_unit_type" : "month", "hot_water_cost" : 200, "hot_water_cost_unit_type" : "month", "annual_ground_water_cost" : 1100, "annual_service_charge" : 200, "resident_parking_cost" : 1200, "other_costs" : [{ "name" : "Cost 1", "value" : 200, "unit_type" : "month" } ], "improvement_types" : [ { "name" : "Total refurbishment", "value" : 200, "date": "2016-06-01" }  ], "current_valuation" : 32000, "dream_price" : 42000, "rental_price" : 1000, "floorplan_url" : "some random url", "pictures" : [{"category" : "Front", "url" : "random url" }, { "category" : "Garden", "url" : "Some random url" } ], "property_brochure_url" : "some random url", "video_walkthrough_url" : "some random url", "property_sold_status" : "Under offer", "agreed_sale_value" : 37000, "expected_completion_date" : "2017-03-13", "actual_completion_date" : "2017-04-01", "new_owner_email_id" : "a@b.com" , "vendor_address" : "Some address" } }'
  #### TODO: Validations
  def edit_property_details
    if user_valid_for_viewing?(['Agent', 'Vendor'], params[:udprn].to_i)
    #if true
      udprn = params[:udprn].to_i
      details = params[:details]
      updated_details = PropertyService.new(udprn).edit_details(details, @current_user)
      property_status_type = updated_details[:property_status_type]
      mandatory_attrs = PropertyService::STATUS_MANDATORY_ATTRS_MAP[property_status_type]
      mandatory_attrs ||= PropertyService::STATUS_MANDATORY_ATTRS_MAP['Green']
      missing_fields = mandatory_attrs.select{ |t| updated_details[t].nil? }
      render json: { message: 'Property details edited', response: updated_details, missing_fields: missing_fields, mandatory_fields: mandatory_attrs }, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Fetches details of a property from its vanity url
  ### curl -XGET  'http://localhost/property/details/98-mostyn-avenue-old-roan-liverpool-merseyside-l10-2jq'
  def details_from_vanity_url
    details = PropertyService.fetch_details_from_vanity_url(params[:vanity_url])
    render json: details, status: 200
  end

  ### When a request is made to fetch the historic pricing details for a udprn
  ### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/prices/10966139'
  def historic_pricing
      details = PropertyDetails.historic_pricing_details(params[:udprn].to_i)
      render json: details, status: 200
  end

  ### When a request is made to fetch the updated historic pricing details for a udprn(sale price, current valuation, dream price etc)
  ### curl -XGET -H "Content-Type: application/json" -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c"  'http://localhost/property/pricing/history/10966139'
  def pricing_history
    #if user_valid_for_viewing?(['Agent', 'Vendor'], params[:udprn].to_i)
    if true
      history_data = PropertyService.new(params[:udprn].to_i).calculate_pricing_history
      render json: history_data, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### This route provides all the details of the recent enquiries made by the users on this property
  ### curl -XGET -H "Content-Type: application/json"  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/enquiries/property/10966139'
  def enquiries
    #if user_valid_for_viewing?(['Agent', 'Vendor', 'Developer'], params[:udprn].to_i)
    if true
      cache_response(params[:udprn].to_i, [params[:page], params[:buyer_id], params[:qualifying_stage], params[:rating], params[:archived], params[:closed], params[:count]]) do
        page = params[:page]
        page ||= 0
        page = page.to_i
        udprn = params[:udprn].to_i
        count = params[:count].to_s == 'true'
        is_premium = @current_user.is_premium rescue false
        profile = @current_user.class.to_s
        event_service = EventService.new(udprn: udprn, buyer_id: params[:buyer_id], 
                                     last_time: params[:latest_time], qualifying_stage: params[:qualifying_stage],
                                     rating: params[:rating], archived: params[:archived], is_premium: is_premium, 
                                     closed: params[:closed], count: count, profile: profile)
        if @current_user.is_a?(Agents::Branches::AssignedAgent) && event_service.details[:agent_id].to_i != @current_user.id
          render json: { message: 'The agent does not belong to the property' }, status: 400
        else
          enquiries = event_service.property_specific_enquiry_details(page)
          render json: enquiries, status: 200
        end
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
    #if true
    #  cache_response(params[:udprn].to_i, []) do
        interest_info = Trackers::Buyer.new.interest_info(params[:udprn].to_i)
        render json: interest_info, status: 200
    #  end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  #### From supply table, this action gives the data regarding how many properties are similar to their property.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/supply/10966139'
  def supply_info
    supply_info = Trackers::Buyer.new.supply_info(params[:udprn].to_i)
    render json: supply_info, status: 200
  end

  #### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIi MOtADL0o5NadFJi2Xs4c" 'http://localhost/property/aggregate/supply/10966139'
  def supply_info_aggregate
    #if user_valid_for_viewing?(['Agent', 'Vendor'], params[:udprn].to_i)
    if true
      supply_info = Trackers::Buyer.new.supply_info(params[:udprn].to_i)
      #{"locality":{"Green":0,"Amber":0,"Red":0},"street":{"Green":0,"Amber":0,"Red":0}} 
      supply_info_aggregate = {}
      supply_info[:locality] ||= {"Green"=>0,"Amber"=>0,"Red"=>0}
      supply_info_aggregate[:locality] = supply_info[:locality].map{|k,v| v}.reduce(:+)
      supply_info[:street] ||= {"Green"=>0,"Amber"=>0,"Red"=>0}
      supply_info_aggregate[:street] = supply_info[:street].map{|k,v| v}.reduce(:+)
      supply_info_aggregate[:locality_query_param] = supply_info[:locality_query_param]
      supply_info_aggregate[:street_query_param] = supply_info[:street_query_param]
      render json: supply_info_aggregate, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
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
    search_str = params[:hash_str]
    property_status_type = params[:property_status_type]
    verification_status = params[:verification_status]
    cache_parameters = [:enquiry_type, :type_of_match, :hash_str, :property_status_type, :verification_status, :last_time, :page, :count].map{ |t| params[t].to_s }
    count = params[:count].to_s == 'true'
    cache_response(params[:buyer_id].to_i, cache_parameters) do
      ranking_info = Trackers::Buyer.new.history_enquiries(buyer_id: params[:buyer_id].to_i, enquiry_type: enquiry_type, type_of_match: type_of_match, property_status_type:  property_status_type, hash_str: search_str, verification_status: verification_status, last_time: params[:latest_time], page_number: params[:page], count: count)
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
  #rescue ActiveRecord::RecordNotUnique
  #  render json: { message: 'Sorry, this udprn has already been claimed' }, status: 400
  #rescue Exception
  #  render json: { message: 'Sorry, this udprn has already been claimed' }, status: 400
  end


  #### Attach the vendor to a manually added property without making the vendor force the attributes
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/properties/manually/added/claim/vendor' -d '{ "vendor_id" : 1235, "udprn" : 12649776 }'
  def attach_vendor_to_udprn_manual_for_manually_added_properties
    if user_valid_for_viewing?(['Vendor'], params[:udprn].to_i)
      udprn = params[:udprn].to_i
      vendor_id = @current_user.id
      #### Attach the lead to the agent
      details = PropertyDetails.details(udprn)[:_source]
      Agents::Branches::AssignedAgents::Lead.where(property_id: udprn).where(vendor_id: nil).last.update_attributes(district: details[:district])
      details = { udprn: udprn, vendor_id: vendor_id }
      response, status = PropertyService.new(udprn).update_details(details)
      render json: response, status: status
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Update basic details of a property by a vendor. Part of vendor verification workflow process
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/properties/vendor/basic/10966139/update' -d '{ "beds" : 2, "baths": 190, "receptions" : 34, "property_status_type" : "Green", "vendor_id" : 1, "property_type": "Countryside" }'
  def update_basic_details_by_vendor
    update_basic_details_by_vendor_params
    udprn = params[:udprn].to_i
    body = {}
    vendor_id = params[:vendor_id].to_i
    body[:vendor_id] = vendor_id
    body[:beds] = params[:beds].to_i if params[:beds]
    body[:baths] = params[:baths].to_i if params[:baths]
    body[:receptions] = params[:receptions].to_i if params[:receptions]
    body[:property_status_type] = params[:property_status_type] if params[:property_status_type]
    body[:property_type] = params[:property_type] if params[:property_type]
    body[:dream_price] = params[:dream_price] if params[:dream_price]
    body[:verification_status] = false
    PropertyService.new(udprn).update_details(body)

    ### Update district of manually claimed leads

    render json: { message: 'Successfully updated' }, status: 200
  #rescue Exception => e
  #  render json: { message: "Update failed  #{e}" }, status: 400
  end

  ### Bulk api to filter the udprns which have a vendor attached to them
  ### To know which udprns have been claimed or not
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/properties/filter/claimed' -d '{ "hashes" : ["@_@_@_@_@_@_@_@_23830513"]}'
  def filter_claimed_udprns
    hashes = params[:hashes]
    resp = []
    hashes.each do |each_hash|
      hash_val = { hash_str: each_hash }
      PropertySearchApi.construct_hash_from_hash_str(hash_val)
      udprn = hash_val[:udprn]
      resp.push(udprn) if PropertyDetails.details(udprn)[:_source][:vendor_id].nil?
    end

    render json: resp, status: 200
  end

  #### Udprns and address suggest for postcodes(only unclaimed properties)
  #### curl -XGET 'http://localhost/properties/unclaimed/search/:postcode'
  def unclaimed_properties_for_postcode
    postcode = params[:postcode]
    results, code = PropertyService.get_results_from_es_suggest(postcode.upcase, 1)
    predictions = Oj.load(results)['postcode_suggest'][0]['options']

    if predictions.length > 0
      type = predictions.first['text'].split('|')[0]
      if type == 'unit'
        udprn = predictions.first['text'].split('|')[1]
        details = PropertyDetails.details(udprn)[:_source]
        hash_str = MatrixViewService.form_hash(details, :unit)
        search_params = { hash_str: hash_str, hash_type: 'unit', results_per_page: 1000 }
        api = PropertySearchApi.new(filtered_params: search_params)
        results, code = api.filter
        results = results[:results].select{ |t| t[:vendor_id].nil? }
        render json: results, status: code.to_i
      else
        render json: { message: 'Invalid postcode search' }, status: 400
      end
    else
      render json: { message: 'Invalid postcode search' }, status: 400
    end
  end

  ### This api allows a renter to tag these attribute
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo3LCJleHAiOjE0ODUxODUwMTl9.7drkfFR5AUFZoPxzumLZ5TyEod_dLm8YoZZM0yqwq6U"   'http://localhost/property/claim/renter' -d ' { "udprn" : 4322959, "beds":3, "baths" : 2, "receptions" : 1, "property_type" : "bungalow", "vendor_email" : "renter@prophety.co.uk" }'
  def upload_property_details_from_a_renter
    if user_valid_for_viewing?(['Buyer'], params[:udprn].to_i)
      validate_rent_property_upload_params
      update_hash = {}
      udprn = params[:udprn].to_i
      update_hash[:beds] = params[:beds] if params[:beds].is_a?(Integer)
      update_hash[:baths] = params[:baths] if params[:baths].is_a?(Integer)
      update_hash[:receptions] = params[:receptions] if params[:receptions].is_a?(Integer)
      update_hash[:property_type] = params[:property_type] if params[:property_type].is_a?(String)
      update_hash[:verification_status] = false
      update_hash[:renter_id] = @current_user.id
      PropertyService.new(udprn).update_details(update_hash)
      @current_user.send_vendor_email(params[:vendor_email], udprn)
      render json: { message: 'Property details have been updated successfully' }, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end

  end

  ### New tags for a particular field can be added using this api
  ### curl -XPOST   -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo3LCJleHAiOjE0ODUxODUwMTl9.7drkfFR5AUFZoPxzumLZ5TyEod_dLm8YoZZM0yqwq6U" 'http://localhost/tags/property_style' 
  def add_new_tags
    if user_valid_for_viewing?(['Agent', 'Developer', 'Vendor'], params[:udprn].to_i)
      tags = params[:tags]
      field = params[:field]
      field_type = FieldValueStore::FIELD_TYPE_ARR.index(field.to_sym)
      tags ||= [] if !tags.is_a?(Array)
      tags.each{ |tag| FieldValueStore.create!(field_type: field_type, name: tag) }
      render json: { message: "Tags have been added successfully to the #{field}", tags: tags }, status: 201
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Show all tags for a particular field
  ### curl -XGET   -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo3LCJleHAiOjE0ODUxODUwMTl9.7drkfFR5AUFZoPxzumLZ5TyEod_dLm8YoZZM0yqwq6U" 'http://localhost/tags/property_style' 
  def show_tags
    if user_valid_for_viewing?(['Agent', 'Developer', 'Vendor'], params[:udprn].to_i)
      field = params[:field]
      field_type = FieldValueStore::FIELD_TYPE_ARR.index(field.to_sym)
      tags = FieldValueStore.where(field_type: field_type).pluck(:name)
      render json: tags, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end


  ### Predictions for the tags
  ### curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo3LCJleHAiOjE0ODUxODUwMTl9.7drkfFR5AUFZoPxzumLZ5TyEod_dLm8YoZZM0yqwq6U" " 'http://localhost/predict/tags?field=property_style&str=Exampl' 
  def predict_tags
    if user_valid_for_viewing?(['Agent', 'Developer', 'Vendor'], params[:udprn].to_i)
      field = params[:field]
      field_type = FieldValueStore::FIELD_TYPE_ARR.index(field.to_sym)
      search_str = params[:str]
      tags = FieldValueStore.where(field_type: field_type).where(" name LIKE '#{search_str}%'").pluck(:name)
      render json: tags, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
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

  def validate_rent_property_upload_params
    params.require(:beds)
    params.require(:baths)
    params.require(:receptions)
    params.require(:property_type)
    params.require(:vendor_email)
  end

  def set_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Expose-Header'] = 'latest_time'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD'
    headers['Access-Control-Allow-Headers'] = '*,x-requested-with,Content-Type,If-Modified-Since,If-None-Match,latest_time'
    headers['Access-Control-Max-Age'] = '86400'
  end

end
