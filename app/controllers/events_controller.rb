class EventsController < ApplicationController
  include EventsHelper

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
    details = PropertyDetails.details(property_id)['_source']
    property_status_type = details['property_status_type']
    agent_id = params[:agent_id] || details['agent_id']
    message = 'NULL' if message.nil?
    response = insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)

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
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/new/1234'
  def agent_new_enquiries
    enquiry_type = params[:enquiry_type]
    type_of_match = params[:type_of_match]
    qualifying_stage = params[:qualifying_stage]
    rating = params[:rating]
    buyer_status = params[:buyer_status]
    buyer_funding = params[:buyer_funding]
    buyer_biggest_problem = params[:buyer_biggest_problem]
    buyer_chain_free = params[:buyer_chain_free]
    search_str = params[:search_str]
    budget_from = params[:budget_from]
    budget_to = params[:budget_to]
    response = []
    # Rails.logger.info("#{params[:agent_id].to_i}_#{enquiry_type}_#{type_of_match}_#{qualifying_stage}_#{rating}_#{buyer_status}_#{buyer_funding}_#{buyer_biggest_problem}_#{buyer_chain_free}_#{search_str}_#{budget_from}_#{budget_to}")
    response = Trackers::Buyer.new.property_enquiry_details_buyer(params[:agent_id].to_i, enquiry_type, type_of_match, qualifying_stage, rating, buyer_status, buyer_funding, buyer_biggest_problem, buyer_chain_free, search_str, budget_from, budget_to) if params[:agent_id]
    render json: response, status: 200
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
  def recent_properties_for_quotes
    services_required = params[:services_required]
    quote_status = params[:quote_status]
    payment_terms = params[:payment_terms]
    search_str = params[:search_str]
    response = []
    response = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_quotes(payment_terms, services_required, quote_status, search_str) if params[:agent_id]
    render json: response, status: 200
  end


  #### For agents the leads page has to be shown in which the recent properties have been claimed
  #### Those properties have just been claimed recently in the area
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/claims?agent_id=1234'
  def recent_properties_for_claim
    response = []
    status = params[:status]
    response = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_claim(status) if !params[:agent_id].nil?
    render json: response, status: 200
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
  #### Filters on property_status_type, ads
  def detailed_properties
    response = []
    status = [ 
               Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New'],
               Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
             ]
    if !params[:agent_id].nil?
      #### TODO: Need to fix agents quotes when verified by the vendor
      search_params = { limit: 10000, fields: 'udprn' }
      search_params[:agent_id] = params[:agent_id].to_i
      search_params[:property_status_type] = 'Green'
      search_params[:verification_status] = true
      search_params[:ads] = params[:ads] if params[:ads] == true
      property_ids = lead_property_ids = other_ids = udprns = []
      if !(params[:ads].to_s == 'true' || params[:ads].to_s == 'false')
        property_ids = Agents::Branches::AssignedAgents::Quote.where(agent_id: params[:agent_id], status: status).pluck(:property_id)
        lead_property_ids = Agents::Branches::AssignedAgents::Lead.where(agent_id: params[:agent_id].to_i).pluck(:property_id)
        other_ids = udprns + lead_property_ids + property_ids
      else
        search_params[:ads] = params[:ads]
      end

      api = PropertySearchApi.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      udprns = body.map { |e| e['udprn'] }

      ### Get all properties for whom the agent has won leads
      property_ids = other_ids + udprns
      Rails.logger.info(property_ids)
      response = property_ids.uniq.map { |e| Trackers::Buyer.new.push_events_details(PropertyDetails.details(e)) }
      response = response.select{ |t| t['_source']['property_status_type'] == params[:property_status_type] } if params[:property_status_type]
    end
    render json: response, status: 200
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
    render json: response, status: sta
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

end
