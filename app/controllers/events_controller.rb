class EventsController < ApplicationController
  include EventsHelper
  include CacheHelper
  before_filter :set_headers
  around_action :authenticate_agent_and_buyer, only: [ :process_event, :book_calendar, :show_calendar, :show_calendar_booking_details, :delete_calendar_viewing ]
  around_action :authenticate_agent_and_vendor, only: [ :unique_buyer_count ]
  around_action :authenticate_agent_and_developer, only: [ :buyer_stats_for_enquiry, :agent_new_enquiries ]
  around_action :authenticate_buyer, only: [ :buyer_calendar_events ]

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
    if !(Event::ENQUIRY_EVENTS.include?(event)) || (daily_enquiry_count <= PropertyBuyer::BUYER_ENQUIRY_LIMIT[buyer.is_premium.to_s] || @current_user.class.to_s != 'PropertyBuyer')
      response = insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)
      if response[:error].nil?
        render json: { 'message' => 'Successfully processed the request', response: response }, status: 200
      else
        render json: response, status: 400
      end
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
    #cache_response(params[:agent_id].to_i, cache_parameters) do
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
    #end
  end

  #### Get buyer stats for an enquiry
  #### curl -XGET  -H "Authorization: eyJ0eXAi" 'http://localhost/agents/buyer/enquiry/stats/:enquiry_id'
  def buyer_stats_for_enquiry
    enquiry_id = params[:enquiry_id].to_i
    event = Event.unscope(where: :is_developer).where(id: enquiry_id).select([:buyer_id, :udprn, :agent_id]).first
    if event
      if event.agent_id == @current_user.id
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
  #### When a buyer clicks on the unsubscibe link in the mails he is no longer subscribed to that event for that property
  #### udprn param is mandatory
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/events/unsubscribe?buyer_id=1&udprn=11111111&event=interested_in_viewing'
  def unsubscribe
    buyer_id = params[:buyer_id].to_i
    subscribed_events = Events::Track.where(buyer_id: buyer_id)
    subscribed_events.each { |event| event.active = false && event.save! }
    render json: {message: "Unsubscribed"}, status: 200
  end

  ### Get unique buyer count for property's enquiries
  ### curl -XGET 'http://localhost/enquiries/unique/buyer/count/:udprn'
  def unique_buyer_count
    udprn = params[:udprn].to_i
    old_stats_flag = params[:old_stats_flag].to_s == 'true'
    query_model = Event
    query_model = query_model.unscoped(where: :is_archived).where(is_archived: true) if old_stats_flag
    unique_buyer_count = query_model.where(udprn: udprn).pluck(:buyer_id).uniq.count
    render json: unique_buyer_count, status: 200
  end

  ### Shows the calendar to the agents and buyers about the property's viewing
  ### curl -XGET 'http://localhost/property/viewing/availability/:udprn?start_time=%222018-08-20T16:48:00.035Z%22&end_time=%222018-08-26T16:48:00.036Z%22'
  def show_calendar
    udprn = params[:udprn].to_i
    details = PropertyDetails.details(udprn)[:_source]
    end_time = Time.parse(params[:end_time])
    start_time = Time.parse(params[:start_time])
    if details[:source]
      property_status_type = details[:property_status_type]
      if property_status_type == 'Green' && PropertyService::REVERSE_SOURCE_MAP[details[:source].to_i] == :quote_vendor_invite
        vendor = Vendor.where(id: details[:vendor_id].to_i).select([:working_hours, :id]).first
        working_hours = nil
        Rails.logger.info("WORKING_HOURS #{vendor.working_hours}")
        working_hours = vendor.working_hours if vendor
        results = VendorCalendarUnavailability.where(vendor_id: vendor.id).where("((end_time > ?) OR (end_time < ?)) AND ((start_time > ?) OR (start_time < ?))", start_time, end_time, start_time, end_time)
        render json: { unavailabilities: results, viewing_entity: 'vendor', working_hours: working_hours }, status: 200
      else
        agent = Agents::Branches::AssignedAgent.where(id: details[:agent_id].to_i).select([:working_hours, :id]).first
        working_hours = nil
        Rails.logger.info("WORKING_HOURS #{agent.working_hours}")
        working_hours = agent.working_hours if agent
        results = AgentCalendarUnavailability.where(agent_id: agent.id).where("((end_time > ?) OR (end_time < ?)) AND ((start_time > ?) OR (start_time < ?))", start_time, end_time, start_time, end_time)
        render json: { unavailabilities: results, viewing_entity: 'agent', working_hours: working_hours }, status: 200
      end
    else
      render json: { message: 'No calendar has been assigned to this property' }, status: 400
    end
  end

  ### Book the calendar to the agents and buyers about the property's viewing
  ### curl -XPOST 'http://localhost/property/book/viewing/:udprn' -d  '{ "buyer_id" : 121, "start_time":"2018-09-12 01:02:03", "end_time" : "2018-09-09 01:03:03" }'
  def book_calendar
    udprn = params[:udprn].to_i
    details = PropertyDetails.details(udprn)[:_source]
    end_time = Time.parse(params[:end_time])
    start_time = Time.parse(params[:start_time])
    if details[:source]
    #if true
      property_status_type = details[:property_status_type]
      if property_status_type == 'Green' && PropertyService::REVERSE_SOURCE_MAP[details[:source].to_i] == :quote_vendor_invite
      #if true
        vendor_unavailability = VendorCalendarUnavailability.create!(
          buyer_id: params[:buyer_id],
          udprn: udprn,
          start_time: Time.parse(params[:start_time]),
          end_time: Time.parse(params[:end_time]),
          vendor_id: details[:vendor_id]
        )
        render json: { message: 'Created an invite in the calendar', details: vendor_unavailability }, status: 200
      else
        response, status = EventService.new(udprn: udprn, buyer_id: params[:buyer_id].to_i, agent_id: details[:agent_id].to_i).schedule_viewing(start_time.to_s, end_time.to_s, 'book_viewing')
        render json: response, status: status
      end
    else
      render json: { message: 'No calendar has been assigned to this property' }, status: 400
    end
  end

  ### Show detail about a calendar booking
  ### curl -XGET 'http://localhost/viewing/details/:id' 
  def show_calendar_booking_details
    id = params[:id].to_i
    viewing = AgentCalendarUnavailability.where(id: id).last
    if viewing
      enquiry_id = viewing.event_id
      event = Event.find(enquiry_id)
      result = Enquiries::AgentService.process_enquiries_result([event], event.agent_id)
      render json: { details: result.first }, status: 200
    else
      render json: { message: 'Viewing does not exist' }, status: 400
    end
  end

  ### Edit the start and the end time of the viewing
  ### curl -XPOST -H "Content-Type: application/json" -H "Authorization: zbdxhsaba" 'http://localhost/events/viewing/edit/:id' -d '{"start_time" : "2018-10-21 09:00:00", "end_time":"2018-10-21 09:30:00", "source": "agent"}'
  def edit_calendar_viewing
    id = params[:id].to_i
    viewing = AgentCalendarUnavailability.where(id: id).last
    viewing ||= VendorCalendarUnavailability.where(id: id).last
    if viewing.class.to_s == 'AgentCalendarUnavailability'
      viewing.start_time = Time.parse(params[:start_time])
      Event.where(udprn: viewing.udprn, buyer_id: viewing.buyer_id, agent_id: viewing.agent_id).update_all(scheduled_visit_time: params[:start_time], scheduled_visit_end_time: params[:end_time] )
      viewing.end_time = Time.parse(params[:end_time])
      viewing.save!
      render json: { details: viewing }, status: 200
    elsif viewing.class.to_s == 'VendorCalendarUnavailability'
      viewing.start_time = Time.parse(params[:start_time])
      viewing.end_time = Time.parse(params[:end_time])
      Event.where(udprn: viewing.udprn, buyer_id: viewing.buyer_id, agent_id: viewing.agent_id).update_all(schedule_visit_time: params[:start_time], scheduled_visit_end_time: params[:end_time])
      viewing.save!
      render json: { details: viewing }, status: 200
    else
      render json: { message: 'Viewing does not exist' }, status: 400
    end
  end

  ### Delete the viewing
  ### curl -XPOST -H "Content-Type: application/json" -H "Authorization: zbdxhsaba" 'http://localhost/events/viewing/delete/:id?source=agent' 
  def delete_calendar_viewing
    id = params[:id].to_i
    viewing = AgentCalendarUnavailability.where(id: id).last
    viewing ||= VendorCalendarUnavailability.where(id: id).last
    Event.where(udprn: viewing.udprn, buyer_id: viewing.buyer_id, agent_id: viewing.agent_id).update_all(stage: Event::EVENTS[:qualifying_stage])
    viewing.delete
    render json: { message: 'Viewing has been deleted' }, status: 200
  end

  ### Delete the viewing by enquiry id
  ### curl -XPOST -H "Content-Type: application/json" -H "Authorization: zbdxhsaba" 'http://localhost/events/viewing/enquiry/delete/:enquiry_id'
  def delete_calendar_viewing_by_enquiry
    enquiry_id = params[:enquiry_id].to_i
    event = Event.where(id: enquiry_id).last
    if event
      AgentCalendarUnavailability.where(udprn: event.udprn, buyer_id: event.buyer_id, agent_id: event.agent_id).delete_all
      Event.where(udprn: event.udprn, buyer_id: event.buyer_id, agent_id: event.agent_id).update_all(stage: Event::EVENTS[:qualifying_stage])
      render json: { message: 'Viewing has been deleted' }, status: 200
    else
      render json: { message: 'Viewing with the passed enquiry id does not exist' }, status: 404
    end
  end

  ### Edit the viewing by enquiry id
  ### curl -XPOST -H "Content-Type: application/json" -H "Authorization: zbdxhsaba" 'http://localhost/events/viewing/enquiry/edit/:enquiry_id'
  def edit_calendar_viewing_by_enquiry
    enquiry_id = params[:enquiry_id].to_i
    event = Event.where(id: enquiry_id).last
    if event
      Event.where(udprn: event.udprn, buyer_id: event.buyer_id, agent_id: event.agent_id).update_all(scheduled_visit_time: params[:start_time], scheduled_visit_end_time: params[:end_time] )
      AgentCalendarUnavailability.where(udprn: event.udprn, buyer_id: event.buyer_id, agent_id: event.agent_id).update_all(scheduled_visit_time: params[:start_time], scheduled_visit_end_time: params[:end_time])
      render json: { message: 'Viewing has been edited' }, status: 200
    else
      render json: { message: 'Viewing with the passed enquiry id does not exist' }, status: 404
    end
  end

  ### Buyer's calendar events
  ### curl -XGET -H "Content-Type: application/json" -H "Authorization: zbdxhsaba" 'http://localhost/events/viewings/buyer'
  def buyer_calendar_events
    buyer = @current_user
    calendar_events = AgentCalendarUnavailability.where(buyer_id: buyer.id)
    render json: { calendar_events: calendar_events }, status: 200
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

  def authenticate_buyer
    if user_valid_for_viewing?(['Buyer'])
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

  def authenticate_agent_and_vendor
    if user_valid_for_viewing?(['Agent','Vendor', 'Developer'])
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

