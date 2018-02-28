class EventsController < ApplicationController
  include EventsHelper
  include CacheHelper
  before_filter :set_headers
  around_action :authenticate_agent_and_buyer, only: [ :process_event ]
  around_action :authenticate_agent_and_developer, only: [ :buyer_stats_for_enquiry, :agent_new_enquiries ]

  ### List of params
  ### :udprn, :event, :message, :type_of_match, :buyer_id, :agent_id
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "property_tracking", "message" : null, "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  
  ### An example of saved search pings
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "save_search_hash", "message" : "\{\"search_hash\" : \{ \"min_beds\" : 2, \"max_beds\" : 3, \"min_baths\" : 1, \"max_baths\" : 2, \"hash_str\" : \"HEREFORD_City Centre_Loder Drive\", \"hash_type\" = \"Text\"  \} \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  
  ### An example of property getting sold
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "sold", "message" : "\{\"final_price\" : 300000, \"exchange_of_contracts\" : \"2016-11-23\" \}" , "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  def process_event
    property_status_type = Event::PROPERTY_STATUS_TYPES[params[:property_status_type]]
    buyer_id = params[:buyer_id]
    buyer_id ||= 1
    event = Event::EVENTS.with_indifferent_access[params[:event]]
    #### Search hash of a message
    message = params[:message]
    type_of_match = params[:type_of_match] || "perfect"
    type_of_match = "perfect" if type_of_match == 'normal'
    type_of_match = Event::TYPE_OF_MATCH[type_of_match.downcase.to_sym]
    # type_of_match = Event::TYPE_OF_MATCH.with_indifferent_access[params[:type_of_match]]
    property_id = params[:udprn]
    property_status_type = params[:property_status_type]
    agent_id = params[:agent_id]
    agent_id ||= 0
    message ||= nil
    daily_enquiry_count = Event.where(buyer_id: buyer_id).where('created_at > ?', 24.hours.ago).count
    buyer = PropertyBuyer.where(id: buyer_id).last
    if daily_enquiry_count <= PropertyBuyer::BUYER_ENQUIRY_LIMIT[buyer.is_premium.to_s] || @current_user.class.to_s != 'PropertyBuyer'
      response = insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)
      render json: { 'message' => 'Successfully processed the request', response: response }, status: 200
    else
      render json: { 'message' => 'Buyer enquiry limit exceeded' }, status: 400
    end
    
    ### TODO: Offload to Sidekiq
    if params[:event] == "offer_made_stage"
      #property_buyers = Event.where(event: event).where(udprn: property_id).select("buyer_name, buyer_email").as_json
      #BuyerMailer.offer_made_stage_emails(property_buyers, details['address']).deliver_now
    end
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
    param_list = [ :enquiry_type, :type_of_match, :stage, :rating, :buyer_status, :buyer_funding, 
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
      results, count = Enquiries::AgentService.new(agent_id: params[:agent_id].to_i)
                                              .new_enquiries(params[:enquiry_type], params[:type_of_match], params[:stage],
                                                             params[:rating], params[:hash_str], 'Sale', last_time, is_premium,
                                                             buyer_id, params[:page], archived, closed, count, old_stats_flag) 
         
      final_response = (!results.is_a?(Fixnum) && results.empty?) ? { enquiries: results, message: 'No enquiries to show', count: count } : { enquiries: results, count: count }
      render json: final_response, status: status
    end
  end

  #### Get buyer stats for an enquiry
  #### curl -XGET  -H "Authorization: eyJ0eXAi" 'http://localhost/agents/buyer/enquiry/stats/:enquiry_id'
  def buyer_stats_for_enquiry
    enquiry_id = params[:enquiry_id].to_i
    event = Event.unscope(where: :is_developer).where(id: enquiry_id).select([:buyer_id, :udprn, :agent_id]).first
    if event
      if event.agent_id == 272
        agent_service = Enquiries::AgentService
        view_ratio = agent_service.buyer_views(event.buyer_id, event.udprn)
        enquiry_ratio = agent_service.buyer_enquiries(event.buyer_id, event.udprn)
        render json: { views: view_ratio, enquiries: enquiry_ratio }
      else
        render json: { message: 'Agent is not attached to the property' }, status: 400
      end
    else
      render json: { message: 'Enquiry not found' }, status: 404
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

  #### TODO - Make it token based (Apply some authentication)
  #### When a buyer clicks on the unsubscibe link in the mails he is no longer subscribed to that event
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/events/unsubscribe?buyer_id=1&udprn=11111111&event=interested_in_viewing'
  def unsubscribe
    buyer_id = params[:buyer_id]
    udprn = params[:udprn]
    event = Event::EVENTS[params[:event].to_sym]
    if buyer_id && udprn && event
      type_of_tracking = Event::REVERSE_EVENTS[event.to_i]
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

  def set_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Expose-Header'] = 'latest_time'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD'
    headers['Access-Control-Allow-Headers'] = '*,x-requested-with,Content-Type,If-Modified-Since,If-None-Match,latest_time'
    headers['Access-Control-Max-Age'] = '86400'
  end

  def authenticate_agent_and_developer
    if user_valid_for_viewing?(['Agent', 'Developer'])
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  def authenticate_agent_and_buyer
    if user_valid_for_viewing?(['Agent','Buyer', 'Developer'])
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  def authenticate_agent
    if user_valid_for_viewing?(['Agent'])
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  def user_valid_for_viewing?(klasses=[])
    if !klasses.empty?
      result = nil
      klasses.each do |klass|
        @current_user ||= AuthorizeApiRequest.call(request.headers, klass).result
      end
      @current_user
    end
  end

end

