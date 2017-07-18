class EventsController < ApplicationController
  include EventsHelper
  include CacheHelper

  ### List of params
  ### :udprn, :event, :message, :type_of_match, :buyer_id, :agent_id
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "property_tracking", "message" : null, "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  
  ### An example of saved search pings
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "save_search_hash", "message" : "\{\"search_hash\" : \{ \"min_beds\" : 2, \"max_beds\" : 3, \"min_baths\" : 1, \"max_baths\" : 2, \"hash_str\" : \"HEREFORD_City Centre_Loder Drive\", \"hash_type\" = \"Text\"  \} \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  
  ### An example of property getting sold
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "sold", "message" : "\{\"final_price\" : 300000, \"exchange_of_contracts\" : \"2016-11-23\" \}" , "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  def process_event
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[params[:property_status_type]]
    buyer_id = params[:buyer_id]
    buyer_id ||= 1
    event = Trackers::Buyer::EVENTS.with_indifferent_access[params[:event]]
    #### Search hash of a message
    message = params[:message]
    type_of_match = params[:type_of_match] || "perfect"
    type_of_match = "perfect" if type_of_match == 'normal'
    type_of_match = Trackers::Buyer::TYPE_OF_MATCH[type_of_match.downcase.to_sym]
    # type_of_match = Trackers::Buyer::TYPE_OF_MATCH.with_indifferent_access[params[:type_of_match]]
    property_id = params[:udprn]
    details = PropertyDetails.details(property_id)
    property_status_type = details['_source']['property_status_type']
    agent_id = params[:agent_id] || details['_source']['agent_id']
    message = 'NULL' if message.nil?
    response = insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)
    
    ### TODO: Offload to Sidekiq
    if params[:event] == "offer_made_stage"
      property_buyers = Event.where(event: event).where(udprn: property_id).select("buyer_name, buyer_email").as_json
      BuyerMailer.offer_made_stage_emails(property_buyers, details['address']).deliver_now
    end
    Rails.logger.info("COMPLETED")
    render json: { 'message' => 'Successfully processed the request', response: response }, status: 200
  end

  #### For agents implement filter of agents group wise, company wise, branch wise, location wise,
  #### and agent_id wise. The agent employee is the last missing layer.
  ####  curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234'
  #### Three types of filters i) Verification status and property status type
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234?verification_status=true&property_status_type=Green'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234?verification_status=false&property_status_type=Red'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234?verification_status=true&property_status_type=Green'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234?verification_status=true&property_status_type=Rent'
  def agent_enquiries_by_property
    property_status_type = params[:property_status_type]
    verification_status = params[:verification_status]
    ads = params[:ads]
    search_str = params[:search_str]
    response = []
    response = Trackers::Buyer.new.search_latest_enquiries(params[:agent_id].to_i, property_status_type, verification_status, ads, search_str) if params[:agent_id]

    render json: response, status: 200
  end

  #### For agents implement filter of agents group wise, company wise, branch, location wise,
  #### and agent_id wise. 
  #### New Changes and additions
  #### The leads can be filtered as well. Four different kind of filters apply. 
  #### i) Type of buyer enquiry
  #### ii) Type of match
  #### iii) Qualifying stage
  #### iv) Rating
  #### v) By Buyer's funding type, chain free, biggest problems etc
  #### v) property_for Sale/Rent
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/new/1234'
  def agent_new_enquiries
    results = []
    final_response = {}
    status = 200
    # Rails.logger.info("#{params[:agent_id].to_i}_#{enquiry_type}_#{type_of_match}_#{qualifying_stage}_#{rating}_#{buyer_status}_#{buyer_funding}_#{buyer_biggest_problem}_#{buyer_chain_free}_#{search_str}_#{budget_from}_#{budget_to}")
#    begin
#      Rails.logger.info "sending response for agent new enquiries => #{response}"
#    rescue => e
#      Rails.logger.error "Error with agent enquiries => #{e}"
#      response = {"enquiries" => results, "message" => "Error in showing enquiries", "details" => e.message}
#      status = 500
#    end
    #params_key = "#{params[:agent_id].to_i}_#{params[:enquiry_type]}_#{params[:type_of_match]}_#{params[:qualifying_stage]}_#{params[:rating]}_#{params[:buyer_status]}_#{params[:buyer_funding]}_#{params[:buyer_biggest_problem]}_#{params[:buyer_chain_free]}_#{params[:search_str]}_#{params[:budget_from]}_#{params[:budget_to]}"
    param_list = [ :enquiry_type, :type_of_match, :qualifying_stage, :rating, :buyer_status, :buyer_funding, 
                   :buyer_biggest_problem, :buyer_chain_free, :search_str, :budget_from, :budget_to, 
                   :property_for ]
    cache_parameters = param_list.map{ |t| params[t].to_s }
    cache_response(params[:agent_id].to_i, cache_parameters) do
      results = Trackers::Buyer.new.property_enquiry_details_buyer(params[:agent_id].to_i, params[:enquiry_type], params[:type_of_match], 
        params[:qualifying_stage], params[:rating], params[:buyer_status], params[:buyer_funding], 
        params[:buyer_biggest_problem], params[:buyer_chain_free], 
        params[:search_str], params[:budget_from], params[:budget_to], params[:udprn], params[:property_for]) if params[:agent_id]
      final_response = results.empty? ? {"enquiries" => results, "message" => "No quotes to show"} : {"enquiries" => results}
      render json: final_response, status: status
    end
  end

  #### For agents the quotes page has to be shown in which all his recent or the new properties in the area
  #### Will be published
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234'
  #### For applying filters i) payment_terms
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&payment_terms=Pay%20upfront'
  #### ii) services_required
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&services_required=Ala%20Carte'
  #### ii) quote_status
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&quote_status=Won'
  #### ii) Rent or Sale
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&property_for=Rent'
  def recent_properties_for_quotes
    cache_parameters = [ :agent_id, :payment_terms, :services_required, :quote_status, :search_str, :property_for ]
    cache_response(params[:agent_id].to_i, cache_parameters) do
      results = []
      response = {}
      status = 200
      begin
        results = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_quotes(params[:payment_terms], params[:services_required], params[:quote_status], params[:search_str], params[:property_for]) if params[:agent_id]
        response = results.empty? ? { quotes: results, message: 'No quotes to show' } : { quotes: results}
      rescue => e
        Rails.logger.error "Error with agent quotes => #{e}"
        response = { quotes: results, message: 'Error in showing quotes', details: e.message}
        status = 500
      end
      
      render json: response, status: status
    end
  end


  #### For agents the leads page has to be shown in which the recent properties have been claimed
  #### Those properties have just been claimed recently in the area
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/claims?agent_id=1234'
  #### For rent properties
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/claims?agent_id=1234&property_for=Rent'
  def recent_properties_for_claim
    cache_parameters = []
    cache_response(params[:agent_id].to_i, cache_parameters) do
      response = {}
      status = 200
      begin
        results = []
        agent_status = params[:status]
        if params[:agent_id].nil?
          response = { message: 'Agent ID missing' }
        else
          results = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_claim(agent_status, params[:property_for])
          response = results.empty? ? { leads: results, message: 'No leads to show'} : { leads: results}
        end
      rescue ActiveRecord::RecordNotFound
        response = { message: 'Agent not found in database' }
        status = 404
      rescue => e
        response = { leads: results, message: 'Error in showing leads', details: e.message}
        status = 500
      end
      Rails.logger.info "sending response for recent claims property #{response.inspect}"
      render json: response, status: status
    end
  end

  #### When an agent wants to see the property specific statistics(trackings,
  #### views, etc), this API is called. All enquiries regarding properties he is associated to are returned.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/properties?agent_id=1234'
  def property_enquiries
    response = []
    response = Trackers::Buyer.new.property_enquiry_details_buyer(params[:agent_id].to_i) if params[:agent_id]
    render json: response, status: 200
  end


  #### On demand quicklink for all the properties of agents, or group or branch or company
  #### To get list of properties for the concerned agent
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties?agent_id=1234'
  #### Filters on property_for, ads
  def detailed_properties
    cache_parameters = [ :agent_id, :property_status_type, :verification_status, :ads ].map{ |t| params[t].to_s }
    cache_response(params[:agent_id].to_i, cache_parameters) do
      response = {}
      results = []

      unless params[:agent_id].nil?
        #### TODO: Need to fix agents quotes when verified by the vendor
        search_params = { limit: 100, fields: 'udprn' }
        search_params[:agent_id] = params[:agent_id].to_i
        property_status_type = params[:property_status_type]

        property_for = params[:property_for]
        property_for ||= 'Sale'

        if property_for == 'Sale'
          search_params[:property_status_type] = 'Green'
        else
          search_params[:property_status_type] = 'Rent'
          property_status_type = 'Rent'
        end
        search_params[:property_status_type] = property_status_type if property_status_type
        # search_params[:verification_status] = true
        search_params[:ads] = params[:ads] if params[:ads] == true
        property_ids = lead_property_ids = quote_property_ids = active_property_ids = []
        quote_model = Agents::Branches::AssignedAgents::Quote
        lead_model = Agents::Branches::AssignedAgents::Lead
        rent_property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES['Rent']
        if !params[:ads].nil?
          search_params[:ads] = params[:ads]
        elsif property_for == 'Sale' && params[:property_status_type].nil?
          quote_property_ids = quote_model.where(agent_id: params[:agent_id].to_i)
                                          .where.not(property_status_type: rent_property_status_type)
                                          .pluck(:property_id)
          lead_property_ids = lead_model.where(agent_id: params[:agent_id].to_i)
                                        .where.not(property_status_type: rent_property_status_type)
                                        .pluck(:property_id)
          property_ids = lead_property_ids + quote_property_ids
        elsif property_for == 'Rent'  && params[:property_status_type].nil?
          quote_property_ids = quote_model.where(agent_id: params[:agent_id].to_i)
                                          .where(property_status_type: rent_property_status_type)
                                          .pluck(:property_id)
          lead_property_ids = lead_model.where(agent_id: params[:agent_id].to_i)
                                        .where(property_status_type: rent_property_status_type)
                                        .pluck(:property_id)
          property_ids = lead_property_ids + quote_property_ids
        elsif !property_status_type.nil?
          quote_property_ids = quote_model.where(agent_id: params[:agent_id].to_i)
                                          .where(property_status_type: property_status_type)
                                          .pluck(:property_id)
          lead_property_ids = lead_model.where(agent_id: params[:agent_id].to_i)
                                        .where(property_status_type: property_status_type)
                                        .pluck(:property_id)
        end

        api = PropertySearchApi.new(filtered_params: search_params)
        api.apply_filters
        body, status = api.fetch_data_from_es
        active_property_ids = body.map { |e| e['udprn'].to_i }
        ### Get all properties for whom the agent has won leads
        property_ids = (active_property_ids + property_ids).uniq
        Rails.logger.info("property ids found for detailed properties (agent) = #{property_ids}")
        results = property_ids.uniq.map { |e| Trackers::Buyer.new.push_events_details(PropertyDetails.details(e)) }
        response = results.empty? ? {"properties" => results, "message" => "No properties to show"} : {"properties" => results}
        Rails.logger.info "Sending results for detailed properties (agent) => #{results.inspect}"
      else
        response = { message: 'Agent ID mandatory for getting properties' }
      end
      Rails.logger.info "Sending response for detailed properties (agent) => #{response.inspect}"
      render json: response, status: 200
    end
  end

  #### On demand detailed properties for all the properties of agents, or group or branch or company
  #### To get list of properties for the concerned agent
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/quicklinks/properties?agent_id=1234'
  def quicklinks
    response = []
    search_params = { limit: 10000, fields: 'udprn' }
    search_params[:agent_id] = params[:agent_id].to_i
    search_params[:property_status_type] = 'Green'
    search_params[:verification_status] = true
    api = PropertySearchApi.new(filtered_params: search_params)
    api.apply_filters
    body, status = api.fetch_data_from_es
    # Rails.logger.info(body)
    response = body.map { |e| e['udprn'] }
    render json: response, status: status
  end

  #### When an agent click the claim to a property, the agent gets a chance to visit
  #### the picture. The claim needs to be frozen and the property is no longer available
  #### for claiming.
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/property/claim/4745413' -d { "agent_id" : 1235 }
  def claim_property
    property_service = PropertyService.new(params[:udprn].to_i)
    message, status = property_service.claim_new_property(params[:agent_id].to_i)
    render json: { message: message }, status: status
  end

  #### TODO - Make it token based (Apply some authentication)
  #### When a buyer clicks on the unsubscibe link in the mails he is no longer subscribed to that event
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/events/unsubscribe?buyer_id=1&udprn=11111111&event=interested_in_viewing'
  def unsubscribe
    buyer_id = params[:buyer_id]
    udprn = params[:udprn]
    event = Trackers::Buyer::EVENTS[params[:event].to_sym]
    if buyer_id && udprn && event
      subscribed_event = Event.where(buyer_id: buyer_id).where(udprn: udprn).where(event: event).first
      subscribed_event.is_deleted = true
      if subscribed_event.save!
        render json: {message: "Unsubscribed"}, status: 200
      else
        Rails.logger.info("cannot unsubscribe - #{params}")
        render json: {message: "Cannot Unsubscribe"}, status: 400
      end
    end
  end

end
