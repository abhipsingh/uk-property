class EventsController < ApplicationController
  include EventsHelper
  include CacheHelper
  before_filter :set_headers

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
    property_status_type = params[:property_status_type]
    agent_id = params[:agent_id]
    agent_id ||= 0
    message ||= nil
    response = insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)
    
    ### TODO: Offload to Sidekiq
    if params[:event] == "offer_made_stage"
      #property_buyers = Event.where(event: event).where(udprn: property_id).select("buyer_name, buyer_email").as_json
      #BuyerMailer.offer_made_stage_emails(property_buyers, details['address']).deliver_now
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
    hash_str = params[:hash_str]
    last_time = params[:latest_time]
    is_premium = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: params[:agent_id].to_i).select(:is_premium).first.is_premium rescue nil
    buyer_id = params[:buyer_id]
    archived = params[:archived]
    old_stats_flag = params[:old_stats_flag].to_s == 'true'
    response = []
    response = Trackers::Buyer.new.search_latest_enquiries(params[:agent_id].to_i, property_status_type, verification_status, ads, hash_str, last_time, is_premium, buyer_id, params[:page].to_i, archived, old_stats_flag) if params[:agent_id]

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
                   :buyer_biggest_problem, :buyer_chain_free, :hash_str, :budget_from, :budget_to, 
                   :property_for, :archived, :closed, :count ]
    cache_parameters = param_list.map{ |t| params[t].to_s }
    cache_response(params[:agent_id].to_i, cache_parameters) do
      last_time = params[:latest_time]
      is_premium = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: params[:agent_id].to_i).select(:is_premium).first.is_premium rescue nil
      buyer_id = params[:buyer_id]
      archived = params[:archived]
      closed = params[:closed]
      count = params[:count].to_s == 'true'
      old_stats_flag = params[:old_stats_flag].to_s == 'true'
      results = Trackers::Buyer.new.property_enquiry_details_buyer(params[:agent_id].to_i, params[:enquiry_type], params[:type_of_match], 
        params[:qualifying_stage], params[:rating],  
        params[:hash_str], 'Sale', last_time,
        is_premium, buyer_id, params[:page], archived, closed, count, old_stats_flag) if params[:agent_id]
      final_response = (!results.is_a?(Fixnum) && results.empty?) ? {"enquiries" => results, "message" => "No enquiries to show"} : {"enquiries" => results}
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
    cache_parameters = [ :agent_id, :payment_terms, :services_required, :quote_status, :hash_str, :property_for ]
    #cache_response(params[:agent_id].to_i, cache_parameters) do
      results = []
      response = {}
      status = 200
      count = params[:count].to_s == 'true'
      #begin
        agent = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i)
        results = agent.recent_properties_for_quotes(params[:payment_terms], params[:services_required], params[:quote_status], params[:hash_str], 'Sale', params[:buyer_id], agent.is_premium, params[:page], count, params[:latest_time])
        response = (!results.is_a?(Fixnum) && results.empty?) ? {"quotes" => results, "message" => "No claims to show"} : {"quotes" => results}
      #rescue => e
      #  Rails.logger.error "Error with agent quotes => #{e}"
      #  response = { quotes: results, message: 'Error in showing quotes', details: e.message}
      #  status = 500
      #end
      
      render json: response, status: status
    #end
  end


  #### For agents the leads page has to be shown in which the recent properties have been claimed
  #### Those properties have just been claimed recently in the area
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/claims?agent_id=1234'
  #### For rent properties
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/claims?agent_id=1234&property_for=Rent'
  def recent_properties_for_claim
    cache_parameters = []
    #cache_response(params[:agent_id].to_i, cache_parameters) do
      response = {}
      status = 200
      #begin
        results = []
        agent_status = params[:status]
        if params[:agent_id].nil?
          response = { message: 'Agent ID missing' }
        else
          agent = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i)
          owned_property = params[:manually_added] == 'true' ? true : nil
          owned_property = params[:manually_added] == 'false' ? false : owned_property
          count = params[:count].to_s == 'true'
          results = agent.recent_properties_for_claim(agent_status, 'Sale', params[:buyer_id], params[:hash_str], agent.is_premium, params[:page], owned_property, count, params[:latest_time])
          response = (!results.is_a?(Fixnum) && results.empty?) ? {"leads" => results, "message" => "No leads to show"} : {"leads" => results}
        end
#      rescue ActiveRecord::RecordNotFound
#        response = { message: 'Agent not found in database' }
#        status = 404
#      rescue => e
#        response = { leads: results, message: 'Error in showing leads', details: e.message}
#        status = 500
#      end
      #Rails.logger.info "sending response for recent claims property #{response.inspect}"
      render json: response, status: status
    #end
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
  #### curl -XGET 'http://localhost/agents/properties?agent_id=1234'
  #### Filters on property_for, ads
  def detailed_properties
    cache_parameters = [ :agent_id, :property_status_type, :verification_status, :ads , :count, :old_stats_flag].map{ |t| params[t].to_s }
    cache_response(params[:agent_id].to_i, cache_parameters) do
      response = {}
      results = []
      count = params[:count].to_s == 'true'
      old_stats_flag = params[:old_stats_flag].to_s == 'true'

      unless params[:agent_id].nil?
        #### TODO: Need to fix agents quotes when verified by the vendor
        agent = Agents::Branches::AssignedAgent.unscope(where: :is_developer).where(id: params[:agent_id].to_i).select([:id, :is_premium]).first
        if agent
          old_stats_flag = params[:old_stats_flag].to_s == 'true'
          search_params = { limit: 10000}
          search_params[:agent_id] = params[:agent_id].to_i
          property_status_type = params[:property_status_type]

          search_params[:property_status_type] = params[:property_status_type] if params[:property_status_type]
          search_params[:verification_status] = true if params[:verification_status] == 'true'
          search_params[:verification_status] = false if params[:verification_status] == 'false'

          #### Buyer filter
          if params[:buyer_id] && agent.is_premium
            buyer = PropertyBuyer.where(id: params[:buyer_id]).select(:vendor_id).first
            vendor_id = buyer.vendor_id if buyer
            vendor_id ||= nil
            search_params[:vendor_id] = vendor_id if vendor_id
          end

          ### Location filter
          if agent.is_premium && params[:hash_str]
            search_params[:hash_str] = params[:hash_str]
            search_params[:hash_type] = 'Text'
          end

          property_ids = []
          api = PropertySearchApi.new(filtered_params: search_params)
          api.modify_filtered_params
          api.apply_filters

          ### THIS LIMIT IS THE MAXIMUM. CAN BE BREACHED IN AN EXCEPTIONAL CASE
          api.query[:size] = 10000
          udprns, status = api.fetch_udprns

          ### Get all properties for whom the agent has won leads
          property_ids = udprns.map(&:to_i).uniq

          ### If ads filter is applied
          ad_property_ids = PropertyAd.where(property_id: property_ids).pluck(:property_id) if params[:ads].to_s == 'true' || params[:ads].to_s == 'false'

          property_ids = ad_property_ids if params[:ads].to_s == 'true'
          property_ids = property_ids - ad_property_ids if params[:ads].to_s == 'false'
          results = []
          #Rails.logger.info("property ids found for detailed properties (agent) = #{property_ids}")
          if agent.is_premium && count
            results = property_ids.uniq.count
          else
            results = property_ids.uniq.map { |e| Trackers::Buyer.new.push_events_details(PropertyDetails.details(e), agent.is_premium, old_stats_flag) }
            vendor_ids = []
            vendor_id_property_map = {}
            results.each_with_index do |t, index|
              results[index][:ads] = (PropertyAd.where(property_id: t[:udprn]).count > 0) 
              vendor_ids.push(results[index][:vendor_id])
              vendor_id_property_map[results[index][:vendor_id].to_i] ||= []
              vendor_id_property_map[results[index][:vendor_id].to_i].push(index)
            end

            buyers = PropertyBuyer.where(vendor_id: vendor_ids.uniq.compact).select([:status, :buying_status, :vendor_id])

            buyers.each do |buyer|
              indices = vendor_id_property_map[buyer.vendor_id]
              indices.each do |index|
                results[index][:buyer_status] = PropertyBuyer::REVERSE_STATUS_HASH[buyer.status]
                results[index][:buying_status] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer.buying_status]
              end
            end

            vendor_id_property_map = {}

          end

          response = (!results.is_a?(Fixnum) && results.empty?) ? {"properties" => results, "message" => "No properties to show"} : {"properties" => results}
        else
          render json: { message: 'Agent id not found in the db'}, status: 400
        end
        #Rails.logger.info "Sending results for detailed properties (agent) => #{results.inspect}"
      else
        response = { message: 'Agent ID mandatory for getting properties' }
      end
      #Rails.logger.info "Sending response for detailed properties (agent) => #{response.inspect}"
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
  #### curl -XPOST -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/events/property/claim/4745413' 
  def claim_property
    agent = user_valid_for_viewing?('Agent')
    if agent
      if agent.credit >= Agents::Branches::AssignedAgent::LEAD_CREDIT_LIMIT
      #if true
        property_service = PropertyService.new(params[:udprn].to_i)
        message, status = property_service.claim_new_property(params[:agent_id].to_i)
        render json: { message: message }, status: status
      else
        render json: { message: "Credits possessed for leads #{agent.credit},  not more than #{Agents::Branches::AssignedAgent::LEAD_CREDIT_LIMIT} " }, status: 401
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  #### TODO - Make it token based (Apply some authentication)
  #### When a buyer clicks on the unsubscibe link in the mails he is no longer subscribed to that event
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/events/unsubscribe?buyer_id=1&udprn=11111111&event=interested_in_viewing'
  def unsubscribe
    buyer_id = params[:buyer_id]
    udprn = params[:udprn]
    event = Trackers::Buyer::EVENTS[params[:event].to_sym]
    if buyer_id && udprn && event
      type_of_tracking = Trackers::Buyer::REVERSE_EVENTS[event.to_i]
      enum_type_of_tracking = Events::Track::TRACKING_TYPE_MAP[type_of_tracking]
      subscribed_event = Events::Track.where(buyer_id: buyer_id).where(udprn: udprn).where(type_of_tracking: subscribed_event).first
      subscribed_event.active = false
      if subscribed_event.save!
        render json: {message: "Unsubscribed"}, status: 200
      else
        Rails.logger.info("cannot unsubscribe - #{params}")
        render json: {message: "Cannot Unsubscribe"}, status: 400
      end
    end
  end

  private

  def user_valid_for_viewing?(klass)
    #Rails.logger.info(request.headers)
    AuthorizeApiRequest.call(request.headers, klass).result
  end

  def set_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Expose-Header'] = 'latest_time'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD'
    headers['Access-Control-Allow-Headers'] = '*,x-requested-with,Content-Type,If-Modified-Since,If-None-Match,latest_time'
    headers['Access-Control-Max-Age'] = '86400'
  end
end

