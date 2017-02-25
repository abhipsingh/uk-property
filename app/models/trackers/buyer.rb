class Trackers::Buyer

  EVENTS = {
    viewed: 2,
    property_tracking: 3,
    street_tracking: 4,
    locality_tracking: 5,
    interested_in_viewing: 6,
    interested_in_making_an_offer: 7,
    requested_message: 8,
    requested_callback: 9,
    requested_viewing: 10,
    deleted: 11,
    responded_to_email_request: 12,
    responded_to_callback_request: 13,
    responded_to_viewing_request: 14,
    qualifying_stage: 15,
    viewing_stage: 16,
    negotiating_stage: 17,
    offer_made_stage: 18,
    offer_accepted_stage: 19,
    closed_lost_stage: 20,
    closed_won_stage: 21,
    confidence_level: 22,
    visits: 23,
    conveyance_stage: 24,
    contract_exchange_stage: 25,
    completion_stage: 26,
    hot_property: 27,
    warm_property: 28,
    cold_property: 29,
    save_search_hash: 30,
    sold: 31,
    valuation_change: 32,
    dream_price_change: 33
  }

  TYPE_OF_MATCH = {
    perfect: 1,
    potential: 2,
    unlikely: 3
  }

  PROPERTY_STATUS_TYPES = {
    'Green' => 1,
    'Amber' => 2,
    'Red'   => 3
  }

  REVERSE_STATUS_TYPES = PROPERTY_STATUS_TYPES.invert

  REVERSE_TYPE_OF_MATCH = TYPE_OF_MATCH.invert

  REVERSE_EVENTS = EVENTS.invert

  CONFIDENCE_ROWS = (1..5).to_a

  ENQUIRY_EVENTS = [
    :interested_in_viewing,
    :interested_in_making_an_offer,
    :requested_message,
    :requested_callback,
    :requested_viewing,
    :viewing_stage
  ]

  TRACKING_EVENTS = [
    :property_tracking,
    :locality_tracking,
    :street_tracking
  ]

  QUALIFYING_STAGE_EVENTS = [
    :qualifying_stage,
    :viewing_stage,
    :offer_made_stage,
    :negotiating_stage,
    :offer_accepted_stage,
    :conveyance_stage,
    :contract_exchange_stage,
    :completion_stage,
    :closed_won_stage,
    :closed_lost_stage
  ]

  #### API Responses for tables

  #### Property specific enquiries
  #### Trackers::Buyer.new.property_enquiries(10966183)
  def property_enquiries(udprn)
    details = PropertyDetails.details(udprn)['_source']
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    total_rows = Event.where(event: events).where(udprn: udprn.to_i).order('created_at DESC')
    buyer_ids = []

    total_rows.each do |each_row|
      new_row = {}
      new_row[:received] = each_row.created_at
      new_row[:type_of_enquiry] = REVERSE_EVENTS[each_row.event]
      new_row['buyer_id'] = each_row.buyer_id
      buyer_ids.push(each_row.buyer_id)

      #### Tracking property id event
      tracking_property_event = EVENTS[:property_tracking]
      event_count = Event.where(event: tracking_property_event).where(buyer_id: each_row.buyer_id).where(udprn: udprn.to_i).count
      new_row[:property_tracking] = event_count == 0 ? true : false
      
      #### Views
      total_views = generic_event_count(EVENTS[:viewed], nil, udprn, :single)
      buyer_views = generic_event_count_buyer(EVENTS[:viewed], nil, udprn, each_row.buyer_id)
      new_row[:views] = buyer_views.to_i.to_s + '/' + total_views.to_i.to_s

      #### Enquiries
      total_enquiries = generic_event_count(ENQUIRY_EVENTS, nil, udprn, :multiple)
      buyer_enquiries = generic_event_count_buyer(ENQUIRY_EVENTS, nil, udprn, each_row.buyer_id)
      new_row[:enquiries] = buyer_enquiries.to_i.to_s + '/' + total_enquiries.to_i.to_s

      #### Type of match
      new_row[:type_of_match] = REVERSE_TYPE_OF_MATCH[each_row.type_of_match]

      #### Qualifying Stage Only shown to the agents
      #Rails.logger.info(future.rows)
      qualifying_events = QUALIFYING_STAGE_EVENTS.map { |e| EVENTS[e] }.join(',')
      qualifying_result = Event.where(udprn: udprn).where(event: qualifying_events).where(buyer_id: each_row.buyer_id).order('created_at DESC').limit(1).first
      new_row[:qualifying] = :qualifying
      new_row[:qualifying] = REVERSE_EVENTS[qualifying_result.event] if qualifying_result

      new_row['scheduled_viewing_time'] = nil
      new_row['scheduled_viewing_time'] = qualifying_result.message['scheduled_viewing_time'] if new_row[:qualifying] == :viewing_stage
      
      new_row['offer_price'] = nil
      new_row['offer_price'] = qualifying_result.message['offer_price'] if new_row[:qualifying] == :offer_made_stage
      
      new_row['offer_date'] = nil
      new_row['offer_date'] = qualifying_result.message['offer_date'] if new_row[:qualifying] == :offer_made_stage

      new_row['expected_completion_date'] = nil
      new_row['expected_completion_date'] = qualifying_result.message['expected_completion_date'] if new_row[:qualifying] == :completion_stage

      # details = PropertyDetails.details(udprn)['_source']
      if details['agent_id']
        hotness_events = [ EVENTS[:hot_property], EVENTS[:cold_property], EVENTS[:warm_property] ]
        event_result = Event.where(buyer_id: each_row.buyer_id).where(event: hotness_events).where(udprn: udprn).order('created_at DESC').limit(1).first
        new_row[:hotness] = REVERSE_EVENTS[event_result.event] if event_result
        new_row[:hotness] ||= 'cold_property'
      end
      new_row[:hotness] ||= nil
      result.push(new_row)
    end

    buyers = PropertyBuyer.where(id: buyer_ids.flatten).select([:id, :email, :full_name, :mobile, :status, :chain_free, :funding, :biggest_problem, :buying_status, :budget_to, :budget_from]).order("position(id::text in '#{buyer_ids.join(',')}')")
    buyer_hash = {}

    buyers.each do |buyer|
      buyer_hash[buyer.id] = buyer
    end

    result.each_with_index do |each_row, index|
      each_row['buyer_status'] = REVERSE_STATUS_TYPES[buyer_hash[each_row['buyer_id']]['status']]
      each_row['buyer_full_name'] = buyer_hash[each_row['buyer_id']]['full_name']
      each_row['buyer_image'] = nil
      each_row['buyer_email'] = buyer_hash[each_row['buyer_id']]['email']
      each_row['buyer_mobile'] = buyer_hash[each_row['buyer_id']]['mobile']
      each_row['chain_free'] = buyer_hash[each_row['buyer_id']]['chain_free']
      each_row['buyer_funding'] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer_hash[each_row['buyer_id']]['funding']]
      each_row['buyer_biggest_problem'] = PropertyBuyer::REVERSE_BIGGEST_PROBLEM_HASH[buyer_hash[each_row['buyer_id']]['biggest_problem']]
      each_row['buyer_buying_status'] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer_hash[each_row['buyer_id']]['buying_status']]
      each_row['buyer_budget_from'] = buyer_hash[each_row['buyer_id']]['budget_from']
      each_row['buyer_budget_to'] = buyer_hash[each_row['buyer_id']]['budget_to']
    end

    result
  end

  #### Agent enquiries latest implementation
  #### Trackers::Buyer.new.search_latest_enquiries(1234)
  def search_latest_enquiries(agent_id, property_status_type=nil, verification_status=nil, ads=nil, search_str=nil)
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    query = Event.where(agent_id: agent_id).where(event: events)
    query = query.search_address_and_buyer_details(search_str) if search_str
    property_ids = query.order('created_at DESC').pluck(:udprn)
    response = property_ids.map { |e| Trackers::Buyer.new.property_and_enquiry_details(agent_id.to_i, e, property_status_type, verification_status, ads) }.compact
  end

  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ########## Property level enquiries ###########################

  ##### To mock this in the console try 
  ##### Trackers::Buyer.new.property_and_enquiry_details(1234, '10966139')
  def property_and_enquiry_details(agent_id, property_id, property_status_type=nil, verification_status=nil, ads=nil)
    details = PropertyDetails.details(property_id)['_source']
    # details = {}
    new_row = {}
    property_enquiry_details(new_row, property_id, details)

    return nil if property_status_type && property_status_type != new_row[:property_status_type]
    return nil if verification_status && verification_status.to_s != new_row[:verification_status].to_s
    return nil if ads && ads.to_s != new_row[:advertised].to_s

    push_agent_details(new_row, agent_id)

    new_row
  end

  #### Push event based additional details to each property details
  ### Trackers::Buyer.new.push_events_details(PropertyDetails.details(10966139))
  def push_events_details(details)
    new_row = {}
    add_details_to_enquiry_row(new_row, details['_source'])
    details['_source'].merge!(new_row)
    details
  end

  #### Push agent specific details
  def push_agent_details(new_row, agent_id)
    keys = [:name, :email, :mobile, :office_phone_number, :image_url]
    agents = Agents::Branches::AssignedAgent.where(id: agent_id).select(keys).as_json
    agents.each { |e| keys.each { |k| new_row[k] = e[k.to_s] } }
  end

  def property_enquiry_details(new_row, property_id, details)
    push_property_details(new_row, details)
    add_details_to_enquiry_row(new_row, details)
  end

  ### For every enquiry row, extract the info from details hash and merge it
  ### with new row
  def push_property_details(new_row, details)
    new_row[:address] = PropertyDetails.address(details)
    new_row[:image_url] = details['photos'][0]
    new_row[:verification_status] = details['verification_status']
    if details['verification_status'] == 'Green'
      keys = ['asking_price', 'offers_price', 'fixed_price']
      
      keys.select{ |t| details.has_key?(t) }.each do |present_key|
        new_row[present_key] = details[present_key]
      end
        
    else
      new_row[:current_valuation] = details['current_valuation']
    end
    new_row[:last_edited] = details['last_listing_updated']
    new_row[:udprn] = details['udprn']
    new_row[:property_type] = details['property_type']
    new_row[:property_status_type] = details['property_status_type']
    new_row[:beds] = details['beds']
    new_row[:baths] = details['baths']
    new_row[:receptions] = details['receptions']
    new_row[:completed_status] = details['agent_status']
    new_row[:listed_since] = (Date.today - Date.parse(details['verification_time'])).to_i
    new_row[:agent_profile_image] = details['agent_employee_profile_image']
    new_row[:advertised] = details['match_type_str'].any? { |e| ['Featured', 'Premium'].include?(e.split('|').last) }
  end

  def add_details_to_enquiry_row(new_row, details)
    table = 'Simple.property_events_buyers_events'
    property_id = details['udprn']

    ### Extra keys to be added
    new_row['total_visits'] = generic_event_count(EVENTS[:viewed], table, property_id, :single)
    new_row['total_enquiries'] = generic_event_count(ENQUIRY_EVENTS, table, property_id, :multiple)
    new_row['trackings'] = generic_event_count(TRACKING_EVENTS, table, property_id, :multiple)
    new_row['requested_viewing'] = generic_event_count(EVENTS[:requested_viewing], table, property_id, :single)
    new_row['offer_made_stage'] = generic_event_count(EVENTS[:offer_made_stage], table, property_id, :single)
    new_row['requested_message'] = generic_event_count(EVENTS[:requested_message], table, property_id, :single)
    new_row['requested_callback'] = generic_event_count(EVENTS[:requested_callback], table, property_id, :single)
    # new_row['impressions'] = generic_event_count(:impressions, table, property_id, :single)
    new_row['deleted'] = generic_event_count(EVENTS[:deleted], table, property_id, :single)
  end

  ##### Trackers::Buyer.new.fetch_filtered_buyer_ids('First time buyer', 'Mortgage approved', 'Funding', true)
  ##### Returns an array of buyer_ids
  def fetch_filtered_buyer_ids(buyer_buying_status=nil, buyer_funding=nil, buyer_biggest_problem=nil, buyer_chain_free=nil, buyer_search_value=nil, budget_from=nil, budget_to=nil)
    pb = PropertyBuyer
    results = pb.where("id > 0")
    results = results.where(buying_status: pb::BUYING_STATUS_HASH[buyer_buying_status]) if buyer_buying_status

    results = results.where(funding: pb::FUNDING_STATUS_HASH[buyer_funding]) if buyer_funding

    results = results.where(biggest_problem: pb::BIGGEST_PROBLEM_HASH[buyer_biggest_problem]) if buyer_biggest_problem

    results = results.where(chain_free: buyer_chain_free) if buyer_chain_free

    results = results.where('budget_from < ?', budget_from.to_i) if budget_from
    results = results.where('budget_to > ?', budget_to.to_i) if budget_to
    results.pluck(:id)
  end

  ####

  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ##### Property level enquiries specific to a buyer but ########
  ##### accessed by an agent. So only associated properties to ##
  ##### the agent are tracked ###################################

  ##### Agent level mock in console for new enquries coming
  ##### Trackers::Buyer.new.property_enquiry_details_buyer(1234, 'requested_message', nil, nil, nil,nil, nil, nil, nil, nil, nil, nil)
  def property_enquiry_details_buyer(agent_id, enquiry_type=nil, type_of_match=nil, qualifying_stage=nil, rating=nil, buyer_buying_status=nil, buyer_funding=nil, buyer_biggest_problem=nil, buyer_chain_free=nil, search_str=nil, budget_from=nil, budget_to=nil, property_udprn=nil)
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    filtered_buyer_ids = []
    ### Process filtered buyer_id only
    filtered_buyer_ids = fetch_filtered_buyer_ids(buyer_buying_status, buyer_funding, buyer_biggest_problem, buyer_chain_free, search_str, budget_from, budget_to)
    filtered_buying_flag = (!buyer_buying_status.nil?) || (!buyer_funding.nil?) || (!buyer_biggest_problem.nil?) || (!buyer_chain_free.nil?)

    ### FIlter only the enquiries which are asked by the caller
    events = events.select{ |t| t == EVENTS[enquiry_type.to_sym] } if enquiry_type

    buyer_filter_flag = buyer_buying_status || buyer_funding || buyer_biggest_problem || buyer_chain_free || budget_from || budget_to
    ### Filter only the type_of_match which are asked by the caller
    query = Event.where(event: events)
    query = query.where(buyer_id: filtered_buyer_ids) if buyer_filter_flag
    query = query.where(type_of_match: type_of_match.to_s.downcase) if type_of_match
    query = query.where(udprn: property_udprn) if property_udprn
    query = query.search_address_and_buyer_details(search_str) if search_str

    total_rows = query.order('created_at DESC').as_json

    qualifying_matches = []
    rating_matches = []
    qualifying_matches_buyer_ids = []
    rating_matches_buyer_ids = []
    buyer_ids = []
    buyer_id_matches = []
    buyer_id_matches_buyer_ids = []

    total_rows.each_with_index do |each_row, index|
      new_row = {}
      new_row['udprn'] = each_row['udprn']
      new_row['received'] = each_row['created_at']
      new_row['type_of_enquiry'] = REVERSE_EVENTS[each_row['event']]
      new_row['time_of_event'] = each_row['created_at'].to_time.to_s
      new_row['buyer_id'] = each_row['buyer_id']
      new_row['type_of_match'] = REVERSE_TYPE_OF_MATCH[each_row['type_of_match']]
      property_id = each_row['udprn']
      push_property_details_row(new_row, property_id)
      add_details_to_enquiry_row_buyer(new_row, property_id, each_row, agent_id)

      ### Check if filtered_buyer_ids is not empty and if its not
      ### Allow only buyer_id which matches each_row['buyer_id']


      if (filtered_buying_flag && filtered_buyer_ids.include?(each_row['buyer_id'].to_i)) || (!filtered_buying_flag)
        
        #### When qualifying_stage is not nil, match the expected and the ones in the result
        if qualifying_stage && new_row[:qualifying].to_s == qualifying_stage.to_s

          qualifying_matches.push(new_row)
          qualifying_matches_buyer_ids.push(each_row['buyer_id'])
        elsif qualifying_stage.nil? && rating.nil?
          buyer_ids.push(each_row['buyer_id'])
          result.push(new_row)
        end

        #### When rating is not nil, match the expected and the ones in the result
        if rating && new_row[:hotness].to_s == rating.to_s
          rating_matches_buyer_ids.push(each_row['buyer_id'])
          rating_matches.push(new_row)
        end

      end

    end

    net_rows = rating_matches | qualifying_matches
    result |= net_rows
    buyer_ids.push((rating_matches_buyer_ids | qualifying_matches_buyer_ids))

    buyers = PropertyBuyer.where(id: buyer_ids.flatten).select([:id, :email, :full_name, :mobile, :status, :chain_free, :funding, :biggest_problem, :buying_status, :budget_to, :budget_from ]).order("position(id::text in '#{buyer_ids.join(',')}')")
    buyer_hash = {}

    buyers.each do |buyer|
      buyer_hash[buyer.id] = buyer
    end

    result.each_with_index do |each_row, index|
      each_row['buyer_status'] = REVERSE_STATUS_TYPES[buyer_hash[each_row['buyer_id']]['status']]
      each_row['buyer_full_name'] = buyer_hash[each_row['buyer_id']]['full_name']
      each_row['buyer_image'] = nil
      each_row['buyer_email'] = buyer_hash[each_row['buyer_id']]['email']
      each_row['buyer_mobile'] = buyer_hash[each_row['buyer_id']]['mobile']
      each_row['chain_free'] = buyer_hash[each_row['buyer_id']]['chain_free']
      each_row['buyer_budget_to'] = buyer_hash[each_row['buyer_id']]['budget_to']
      each_row['buyer_budget_from'] = buyer_hash[each_row['buyer_id']]['budget_from']
      each_row['buyer_funding'] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer_hash[each_row['buyer_id']]['funding']]
      each_row['buyer_biggest_problem'] = PropertyBuyer::REVERSE_BIGGEST_PROBLEM_HASH[buyer_hash[each_row['buyer_id']]['biggest_problem']]
      each_row['buyer_buying_status'] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer_hash[each_row['buyer_id']]['buying_status']]
    end

    result
  end

  def event_ranges(events)
    ranges = []
    new_range = []
    last_event = nil
    events.each do |event|
      if new_range.empty?
        new_range.push(event)
      else
        if (event - last_event.to_i) == 1
        else
          new_range.push(last_event)
          ranges.push(new_range)
          new_range = [event]
        end
      end
      last_event = event
    end

    if !new_range.empty?
      new_range.push(last_event)
    end
    ranges.push(new_range)
    ranges
  end

  def push_property_details_row(new_row, property_id)
    url = "#{Rails.configuration.remote_es_url}/addresses/address/#{property_id}"
    response = Net::HTTP.get(URI.parse(url))
    details = Oj.load(response)['_source']
    push_property_enquiry_details_buyer(new_row, details)
  end

  ### For every enquiry row, extract the info from details hash and merge it
  ### with new row
  def push_property_enquiry_details_buyer(new_row, details)
    #Rails.logger.info(new_row)
    new_row[:address] = details['address'] rescue nil
    new_row[:price] = details['price'] rescue nil
    new_row[:image_url] = details['street_view_image_url'] || details['photo_urls'].first rescue nil
    new_row[:street_view_image_url] = details['street_view_image_url']
    new_row[:photo_url] = details['photo_urls'][0]
    new_row[:udprn] = details['udprn'] rescue nil
    new_row[:status] = details['property_status_type'] rescue nil
    new_row[:offers_over] = details['offers_over'] rescue nil
    new_row[:fixed_price] = details['fixed_price'] rescue nil
    new_row[:asking_price] = details['asking_price'] rescue nil
    new_row[:dream_price] = details['dream_price'] rescue nil
    new_row[:current_valuation] = details['current_valuation'] rescue nil
    new_row[:last_sale_prices] = PropertyHistoricalDetail.where(udprn: details['udprn']).pluck(:price)
    new_row[:verification_status] = details['verification_status'] rescue false
  end

  def add_details_to_enquiry_row_buyer(new_row, property_id, event_details, agent_id)
    new_row['type_of_match'] = REVERSE_TYPE_OF_MATCH[event_details['type_of_match']].to_s.capitalize
    #### Tracking property or not
    tracking_property_event = EVENTS[:property_tracking]
    buyer_id = event_details['buyer_id']
    result = Event.where(buyer_id: buyer_id).where(event: tracking_property_event).where(udprn: property_id).count.as_json

    new_row[:property_tracking] = (result.to_i == 0 ? false : true)
    #### Property is hot or cold or warm
    if agent_id #### This featured is only when agent_id is not nil(i.e. to agents)
      hotness_events = [ EVENTS[:hot_property], EVENTS[:cold_property], EVENTS[:warm_property] ]
      result = Event.where(buyer_id: buyer_id).where(event: hotness_events).where(udprn: property_id).order('created_at DESC').limit(1).first
      new_row[:hotness] = REVERSE_EVENTS[result.event] if result
      new_row[:hotness] ||= 'cold_property'
    end

    ########## Property hotness section ends

    ##### Saved search hashes in message section
    save_search_event = EVENTS[:save_search_hash]
    result = Event.where(buyer_id: buyer_id).where(event: save_search_event).where(udprn: property_id).order('created_at DESC').limit(1).first
    new_row[:search_hash] = result.message.to_json rescue ({}.to_json)
    ##### Saved search hash ends

    #### Views
    total_views = generic_event_count(EVENTS[:viewed], nil, property_id, :single)
    buyer_views = generic_event_count_buyer(EVENTS[:viewed], nil, property_id, buyer_id)
    new_row[:views] = buyer_views.to_i.to_s + '/' + total_views.to_i.to_s

    #### Enquiries
    total_enquiries = generic_event_count(ENQUIRY_EVENTS, nil, property_id, :multiple)
    buyer_enquiries = generic_event_count(ENQUIRY_EVENTS, nil, property_id, :multiple)
    new_row[:enquiries] = buyer_enquiries.to_i.to_s + '/' + total_enquiries.to_i.to_s

    #### Qualifying Stage Only shown to the agents
      #Rails.logger.info(future.rows)
    if agent_id
      qualifying_events = QUALIFYING_STAGE_EVENTS.map { |e| EVENTS[e] }.join(',')
      result = Event.where(agent_id: agent_id).where(buyer_id: buyer_id).where(event: qualifying_events).where(buyer_id: buyer_id).order('created_at DESC')
      result.each do |each_row|
        new_row[:qualifying] = REVERSE_EVENTS[each_row.event]
      end
    end
    new_row
  end

  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ##### Property level enquiries specific to a buyer but ########
  ##### accessed by the vendor/property ownerthe agent are ######
  ##### tracked                                            ######
  ##### Property level mock in console for new enquries coming
  ##### Trackers::Buyer.new.property_enquiry_details_vendor(10966183)
  def property_enquiry_details_vendor(property_id)
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    total_rows = []
    total_rows = Event.where(event: events).where(udprn: property_id).order('created_at DESC').as_json
    buyer_ids = []
    total_rows.each do |each_row|
      new_row = {}
      new_row['received'] = each_row['created_at']
      new_row['type_of_enquiry'] = REVERSE_EVENTS[each_row['event']]
      new_row['time_of_event'] = each_row['created_at'].to_time.to_s
      new_row['buyer_id'] = each_row['buyer_id']
      new_row['type_of_match'] = REVERSE_TYPE_OF_MATCH[each_row['type_of_match']]
      property_id = each_row['udprn']
      push_property_details_row(new_row, property_id)
      add_details_to_enquiry_row_buyer(new_row, property_id, each_row, nil) #### Passing agent_id as nil
      buyer_ids.push(each_row['buyer_id'])
      result.push(new_row)
    end

    buyers = PropertyBuyer.where(id: buyer_ids).select([ :id, :chain_free, :status, :buying_status, :funding, :biggest_problem ]).order("position(id::text in '#{buyer_ids.join(',')}')")
    buyer_hash = {}

    buyers.each do |buyer|
      buyer_hash[buyer.id] = buyer
    end

    result.each_with_index do |each_row, index|
      each_row['buyer_status'] = REVERSE_STATUS_TYPES[buyer_hash[each_row['buyer_id']]['status']]
      #### The following attributes are to be shown as blurred or nil value for vendors
      each_row['buyer_full_name'] = nil  ### Blurred out buyer's name
      each_row['buyer_image'] = nil
      each_row['buyer_email'] = nil
      each_row['buyer_mobile'] = nil
      each_row['chain_free'] = nil
    end

    result
  end


  #### Buyer interest details. To test it, just run the following in the irb
  #### Trackers::Buyer.new.interest_info(10966139)
  def interest_info(udprn)
    aggregated_result = {}
    property_id = udprn.to_i
    current_month = Date.today.month

    event = EVENTS[:viewed]
    monthly_views = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    aggregated_result[:monthly_views] =  monthly_views

    # event = EVENTS[:save_search_hash]
    # monthly_saved_search_hashes = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    # aggregated_result[:save_search_hash] =  monthly_saved_search_hashes

    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    monthly_enquiries = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event IN (#{events.join(',')})").as_json
    aggregated_result[:enquiries] =  monthly_enquiries
    
    event = EVENTS[:property_tracking]
    monthly_property_tracking = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    aggregated_result[:property_tracking] =  monthly_property_tracking

    event = EVENTS[:interested_in_viewing]
    monthly_interested_in_viewing = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    aggregated_result[:interested_in_viewing] =  monthly_interested_in_viewing
    
    event = EVENTS[:interested_in_making_an_offer]
    monthly_interested_in_making_an_offer = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    aggregated_result[:interested_in_making_an_offer] =  monthly_interested_in_making_an_offer

    event = EVENTS[:requested_message]
    monthly_requested_message = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    aggregated_result[:interested_in_making_an_offer] =  monthly_requested_message

    event = EVENTS[:requested_callback]
    results = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    aggregated_result[:requested_callback] =  results

    event = EVENTS[:requested_viewing]
    results = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    aggregated_result[:requested_viewing] =  results

    event = EVENTS[:deleted]
    results = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}").as_json
    aggregated_result[:deleted] =  results

    months = (1..12).to_a
    aggregated_result.each do |key, value|
      present_months = value.map { |e| e['month'].to_i }
      missing_months = months.select{ |t| !present_months.include?(t) }
      missing_months.each do |each_month|
        value.push({ month: each_month.to_s, count: 0 })
      end
    end
    aggregated_result
  end

  #### Track the number of searches of similar properties located around that property
  #### Trackers::Buyer.new.demand_info(10966139)
  def demand_info(udprn)
    details = PropertyDetails.details(udprn.to_i)['_source']
    Rails.logger.info(details)
    table = 'simple.property_events_buyers_events'
    
    #### Similar properties to the udprn
    #### TODO: Remove HACK FOR SOME Results to be shown
    p details['hashes']
    default_search_params = {
      min_beds: details['beds'].to_i - 2,
      max_beds: details['beds'].to_i + 2,
      min_baths: details['baths'].to_i - 2 ,
      max_baths: details['baths'].to_i + 2,
      min_receptions: details['receptions'].to_i - 2,
      max_receptions: details['receptions'].to_i + 2,
      property_status_types: details['property_status_type'],
      fields: 'udprn'
    }
    # p default_search_params

    ### analysis for each of the postcode type
    search_stats = {}
    [ :district, :sector, :unit ].each do |region_type|
      ### Default search stats
      search_stats[region_type] = { perfect_matches: 0, potential_matches: 0, total_matches: 0 }

      search_params = default_search_params.clone
      search_params[region_type] = details[region_type.to_s]
      Rails.logger.info(search_params)
      search_stats[region_type][:value] = details[region_type.to_s] ### Populate the value of sector, district and unit
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      udprns = []
      if status.to_i == 200
        udprns = body.map { |e| e['udprn'] }
      end

      ### Exclude the current udprn from the result
      udprns = udprns - [ udprn.to_s ]
      ### Accumulate data for each udprn
      type_of_match = TYPE_OF_MATCH[:perfect]
      event = EVENTS[:save_search_hash]
      search_stats[region_type][:perfect_matches] = Event.where(udprn: udprns).where(event: event).where(type_of_match: type_of_match).count

      type_of_match = TYPE_OF_MATCH[:potential]
      search_stats[region_type][:potential_matches] = Event.where(udprn: udprns).where(event: event).where(type_of_match: type_of_match).count

      search_stats[region_type][:total_matches] = search_stats[region_type][:perfect_matches] + search_stats[region_type][:potential_matches]

      if search_stats[region_type][:total_matches] > 0
        search_stats[region_type][:perfect_percent] = ((search_stats[region_type][:perfect_matches].to_f/search_stats[region_type][:total_matches].to_f)*100).round(2)
        search_stats[region_type][:potential_percent] = ((search_stats[region_type][:potential_matches].to_f/search_stats[region_type][:total_matches].to_f)*100).round(2)
      else
        search_stats[region_type][:perfect_percent] = nil
        search_stats[region_type][:potential_percent] = nil
      end
    end
    search_stats
  end

  #### Track the number of similar properties located around that property
  #### Trackers::Buyer.new.supply_info(10966139)
  def supply_info(udprn)
    details = PropertyDetails.details(udprn.to_i)['_source'] rescue {}

    #### Similar properties to the udprn
    default_search_params = {
      min_beds: details['beds'].to_i,
      max_beds: details['beds'].to_i,
      min_baths: details['baths'].to_i,
      max_baths: details['baths'].to_i,
      min_receptions: details['receptions'].to_i,
      max_receptions: details['receptions'].to_i,
      property_status_types: details['property_status_type'],
      fields: 'udprn,property_status_type'
    }

    ### analysis for each of the postcode type
    search_stats = {}
    [ :district, :sector, :unit ].each do |region_type|
      ### Default search stats
      search_stats[region_type] = { green: 0, amber: 0, red: 0 }

      search_params = default_search_params.clone
      search_params[region_type] = details[region_type.to_s]
      search_stats[region_type][:value] = details[region_type.to_s] ### Populate the value of sector, district and unit
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es

      ### Accumulate data for each property searched
      body.each do |property_info|
        search_stats[region_type][property_info['property_status_type'].downcase.to_sym] += 1
      end

      search_stats[region_type][:total] = search_stats[region_type][:green] + search_stats[region_type][:amber] + search_stats[region_type][:red]

      if search_stats[region_type][:total] > 0
        search_stats[region_type][:green_percent] = ((search_stats[region_type][:green].to_f/search_stats[region_type][:total].to_f)*100).round(2)
        search_stats[region_type][:amber_percent] = ((search_stats[region_type][:amber].to_f/search_stats[region_type][:total].to_f)*100).round(2)
        search_stats[region_type][:red_percent] = ((search_stats[region_type][:red].to_f/search_stats[region_type][:total].to_f)*100).round(2)
      else
        search_stats[region_type][:green_percent] = nil
        search_stats[region_type][:amber_percent] = nil
        search_stats[region_type][:red_percent] = nil
      end
    end
    search_stats
  end

  #### Track the number of similar properties located around that property
  #### Trackers::Buyer.new.buyer_intent_info(10966139)
  def buyer_intent_info(udprn)
    details = PropertyDetails.details(udprn.to_i)['_source']
    
    #### Similar properties to the udprn
    default_search_params = {
      min_beds: details['beds'].to_i - 2,
      max_beds: details['beds'].to_i + 2,
      min_baths: details['baths'].to_i - 2 ,
      max_baths: details['baths'].to_i + 2,
      min_receptions: details['receptions'].to_i - 2,
      max_receptions: details['receptions'].to_i + 2,
      property_status_types: details['property_status_type'],
      fields: 'udprn'
    }

    ### analysis for each of the postcode type
    search_stats = {}
    [ :district, :sector, :unit ].each do |region_type|
      ### Default search stats
      search_stats[region_type] = { green: 0, amber: 0, red: 0 }

      search_params = default_search_params.clone
      search_params[region_type] = details[region_type.to_s]
      search_stats[region_type][:value] = details[region_type.to_s] ### Populate the value of sector, district and unit
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      udprns = []
      if status.to_i == 200
        udprns = body.map { |e| e['udprn'] }
      end

      ### Exclude the current udprn from the result
      udprns = udprns - [ udprn.to_s ]
      p udprns
      ### Accumulate buyer_id for each udprn
      buyer_ids = []
      event = EVENTS[:save_search_hash]
      buyer_ids = Event.where(event: event).where(udprn: udprns).pluck(:buyer_id).uniq

      ### Extract status of the buyers in bulk
      buyers = PropertyBuyer.where(id: buyer_ids).select([:id, :status])

      buyers.each do |each_buyer_info|
        buyer_status = PropertyBuyer::REVERSE_STATUS_HASH[each_buyer_info.status]
        search_stats[region_type][buyer_status] += 1
      end

      search_stats[region_type][:total] = search_stats[region_type][:green] + search_stats[region_type][:red] + search_stats[region_type][:amber]

      if search_stats[region_type][:total] > 0
        search_stats[region_type][:green_percent] = ((search_stats[region_type][:green].to_f/search_stats[region_type][:total].to_f)*100).round(2)
        search_stats[region_type][:amber_percent] = ((search_stats[region_type][:red].to_f/search_stats[region_type][:total].to_f)*100).round(2)
        search_stats[region_type][:red_percent] = ((search_stats[region_type][:amber].to_f/search_stats[region_type][:total].to_f)*100).round(2)
      else
        search_stats[region_type][:green_percent] = nil
        search_stats[region_type][:amber_percent] = nil
        search_stats[region_type][:red_percent] = nil
      end
    end
    search_stats
  end

  #### Methods for the pie charts have been defined below
  ##### Information about pie charts about the buyer. All related to the buyer
  #### To try this method run the following in the console
  #### Trackers::Buyer.new.buyer_profile_stats(10976419)
  def buyer_profile_stats(udprn)
    result_hash = {}
    property_id = udprn.to_i
    details = PropertyDetails.details(udprn.to_i)['_source'] rescue {}
    event = EVENTS[:save_search_hash]
    buyer_ids = Event.where(event: event).where(udprn: property_id).where(type_of_match: 1).pluck(:buyer_id).uniq

    ### Buying status stats
    buying_status_distribution = PropertyBuyer.where(id: buyer_ids).group(:buying_status).count
    total_count = buying_status_distribution.inject(0) do |result, (key, value)|
      result += value
    end
    buying_status_stats = {}
    buying_status_distribution.each do |key, value|
      buying_status_stats[PropertyBuyer::REVERSE_BUYING_STATUS_HASH[key]] = ((value.to_f/total_count.to_f)*100).round(2)
    end
    PropertyBuyer::BUYING_STATUS_HASH.each { |k,v| buying_status_stats[k] = 0 unless buying_status_stats[k] }

    result_hash[:buying_status] = buying_status_stats

    ### Funding status stats
    funding_status_distribution = PropertyBuyer.where(id: buyer_ids).group(:funding).count
    total_count = funding_status_distribution.inject(0) do |result, (key, value)|
      result += value
    end
    funding_status_stats = {}
    funding_status_distribution.each do |key, value|
      funding_status_stats[PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[key]] = ((value.to_f/total_count.to_f)*100).round(2)
    end
    PropertyBuyer::FUNDING_STATUS_HASH.each { |k,v| funding_status_stats[k] = 0 unless funding_status_stats[k] }
    result_hash[:funding_status] = funding_status_stats

    ### Biggest problem stats
    biggest_problem_distribution = PropertyBuyer.where(id: buyer_ids).group(:biggest_problem).count
    total_count = biggest_problem_distribution.inject(0) do |result, (key, value)|
      result += value
    end
    biggest_problem_stats = {}
    biggest_problem_distribution.each do |key, value|
      biggest_problem_stats[PropertyBuyer::REVERSE_BIGGEST_PROBLEM_HASH[key]] = ((value.to_f/total_count.to_f)*100).round(2)
    end
    PropertyBuyer::BIGGEST_PROBLEM_HASH.each { |k,v| biggest_problem_stats[k] = 0 unless biggest_problem_stats[k] }
    result_hash[:biggest_problem] = biggest_problem_stats

    ### Chain free stats
    chain_free_distribution = PropertyBuyer.where(id: buyer_ids).group(:chain_free).count
    total_count = chain_free_distribution.inject(0) do |result, (key, value)|
      result += value
    end
    chain_free_stats = {}
    chain_free_distribution.each do |key, value|
      chain_free_stats[key] = ((value.to_f/total_count.to_f)*100).round(2)
    end
    chain_free_stats[true] = 0 unless chain_free_stats[true]
    chain_free_stats[false] = 0 unless chain_free_stats[false]
    result_hash[:chain_free] = chain_free_stats
    result_hash
  end

  #### The following method gets the data for qualifying stage and hotness stats
  #### for the agents.
  #### Trackers::Buyer.new.agent_stage_and_rating_stats(10966139)
  def agent_stage_and_rating_stats(udprn)
    aggregate_stats = {}
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    table = 'Simple.property_events_buyers_events'
    property_id = udprn.to_i
    buyer_ids = Event.where(event: events).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq
    ### Filtered out the rows which are outdated

    ### Buyers who are in qualifying stage
    event = EVENTS[:qualifying_stage]
    qualifying_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Buyers who are in viewing scheduled stage
    event = EVENTS[:viewing_stage]
    viewing_scheduled_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Buyers who are in offer made stage
    event = EVENTS[:offer_made_stage]
    offer_made_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Buyers who are in offer made stage
    event = EVENTS[:offer_accepted_stage]
    offer_accepted_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Buyers who are in conveyancing stage
    event = EVENTS[:conveyance_stage]
    conveyance_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Buyers who are in conveyancing stage
    event = EVENTS[:contract_exchange_stage]
    contract_exchange_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Buyers who are in completion stage
    event = EVENTS[:completion_stage]
    completion_stage_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Buyers who are in conveyancing stage
    event = EVENTS[:closed_won_stage]
    closed_won_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq
    
    ### Buyers who are in closed lost stage
    event = EVENTS[:closed_lost_stage]
    closed_lost_buyer_ids = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq
    
    ### Removing the common buyer ids in all the stages
    qualifying_buyer_ids = qualifying_buyer_ids - viewing_scheduled_buyer_ids
    viewing_scheduled_buyer_ids = viewing_scheduled_buyer_ids - offer_made_buyer_ids
    offer_made_buyer_ids = offer_made_buyer_ids - offer_accepted_buyer_ids
    offer_accepted_buyer_ids = offer_accepted_buyer_ids - conveyance_buyer_ids
    conveyance_buyer_ids = conveyance_buyer_ids - completion_stage_buyer_ids
    contract_exchange_buyer_ids = contract_exchange_buyer_ids - completion_stage_buyer_ids
    completion_stage_buyer_ids = completion_stage_buyer_ids - closed_won_buyer_ids - closed_lost_buyer_ids
    unknown_buyer_ids = buyer_ids - ( qualifying_buyer_ids + viewing_scheduled_buyer_ids + offer_made_buyer_ids + offer_accepted_buyer_ids + conveyance_buyer_ids + contract_exchange_buyer_ids + completion_stage_buyer_ids )

    ### Populate the distribution data
    buyer_distribution = {}
    buyer_count = buyer_ids.length.to_f

    ### Unknown
    buyer_distribution[:unknown] = ((unknown_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:unknown_count] = unknown_buyer_ids.length

    ### Qualifying count
    buyer_distribution[:qualifying] = ((qualifying_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:qualifying_count] = qualifying_buyer_ids.length

    ### Viewing scheduled count
    buyer_distribution[:viewing_scheduled] = ((viewing_scheduled_buyer_ids.length.to_f/buyer_count)).round(2)
    buyer_distribution[:viewing_scheduled_count] = viewing_scheduled_buyer_ids.length

    ### Offer made count
    buyer_distribution[:offer_made] = ((offer_made_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:offer_made_count] = offer_made_buyer_ids.length

    ### Offer accepted count
    buyer_distribution[:offer_accepted] = ((offer_accepted_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:offer_accepted_count] = offer_accepted_buyer_ids.length

    ### Conveyancing count
    buyer_distribution[:conveyancing] = ((conveyance_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:conveyancing_count] = conveyance_buyer_ids.length

    ### Contract exchange count
    buyer_distribution[:contract_exchange] = ((contract_exchange_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:contract_exchange_count] = contract_exchange_buyer_ids.length

    ### Completion stage count
    buyer_distribution[:completion_stage] = ((completion_stage_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:completion_stage_count] = completion_stage_buyer_ids.length

    ### Closed won count
    buyer_distribution[:closed_won] = ((closed_won_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:closed_won_count] = closed_won_buyer_ids.length

    ### Closed lost count
    buyer_distribution[:closed_lost] = ((closed_lost_buyer_ids.length.to_f/buyer_count)*100).round(2)
    buyer_distribution[:closed_lost_count] = closed_lost_buyer_ids.length

    aggregate_stats[:buyer_enquiry_distribution] = buyer_distribution

    ######################################################################
    ##### Stats about the rating #########################################
    ######################################################################
    rating_stats = {}

    ### Hot property buyers
    event = EVENTS[:hot_property]
    rating_stats[:hot_property_count] = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq.count
    hot_property_buyers = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Warm property buyers
    event = EVENTS[:warm_property]
    rating_stats[:warm_property_count] = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq.count
    warm_property_buyers = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    ### Cold property buyers
    event = EVENTS[:cold_property]
    rating_stats[:cold_property_count] = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq.count
    cold_property_buyers = Event.where(event: event).where(udprn: property_id).where("created_at > ?", 5.months.ago).pluck(:buyer_id).uniq

    unknown_buyers = buyer_ids - ( hot_property_buyers + warm_property_buyers + cold_property_buyers )
    rating_stats[:unknown_rating_count] = unknown_buyers.length

    rating_stats[:total_count] = ( rating_stats[:hot_property_count] + rating_stats[:warm_property_count] + rating_stats[:cold_property_count] + rating_stats[:unknown_rating_count] )
    rating_stats[:hot_percent] = ((rating_stats[:hot_property_count].to_f/rating_stats[:total_count].to_f)*100).round(2)
    rating_stats[:warm_percent] = ((rating_stats[:warm_property_count].to_f/rating_stats[:total_count].to_f)*100).round(2)
    rating_stats[:cold_percent] = ((rating_stats[:cold_property_count].to_f/rating_stats[:total_count].to_f)*100).round(2)
    rating_stats[:unknown_percent] = ((rating_stats[:unknown_rating_count].to_f/rating_stats[:total_count].to_f)*100).round(2)

    aggregate_stats[:rating_stats] = rating_stats
    aggregate_stats
  end

  #### The following method gets the data for qualifying stage and hotness stats
  #### for the agents.
  #### Trackers::Buyer.new.ranking_stats(10966139)
  def ranking_stats(udprn)
    udprn = udprn.to_i
    property_id = udprn
    details = PropertyDetails.details(udprn)['_source']
    #### Similar properties to the udprn
    default_search_params = {
      min_beds: details['beds'].to_i,
      max_beds: details['beds'].to_i,
      min_baths: details['baths'].to_i,
      max_baths: details['baths'].to_i,
      min_receptions: details['receptions'].to_i,
      max_receptions: details['receptions'].to_i,
      property_status_types: details['property_status_type'],
      fields: 'udprn'
    }

    ### analysis for each of the postcode type
    ranking_stats = {}
    [ :district, :sector, :unit ].each do |region_type|
      ### Default search stats
      ranking_stats[region_type] = {
        property_search_ranking: nil,
        view_ranking: nil,
        total_enquiries_ranking: nil,
        tracking_ranking: nil,
        would_view_ranking: nil,
        would_make_an_offer_ranking: nil,
        message_requested_ranking: nil,
        callback_requested_ranking: nil,
        requested_viewing_ranking: nil,
        deleted_ranking: nil
      }

      search_params = default_search_params.clone
      search_params[region_type] = details[region_type.to_s]
      ranking_stats[region_type][:value] = details[region_type.to_s] ### Populate the value of sector, district and unit
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      udprns = []
      if status.to_i == 200
        udprns = body.map { |e| e['udprn'] }
      end

      ### Accumulate all stats for each udprn
      save_search_hash = {}
      view_hash = {}
      total_enquiry_hash = {}
      tracking_hash = {}
      would_view_hash = {}
      would_make_an_offer_hash = {}
      requested_message_hash = {}
      requested_callback_hash = {}
      requested_viewing_hash = {}
      hidden_hash = {}
      table = nil
      udprns.each do |udprn|
        udprn = udprn.to_i
        event = EVENTS[:save_search_hash]
        save_search_hash[udprn] = generic_event_count(event, table, property_id).to_i

        event = EVENTS[:viewed]
        view_hash[udprn] = generic_event_count(event, table, property_id).to_i

        total_enquiry_hash[udprn] = generic_event_count(ENQUIRY_EVENTS, table, property_id, :multiple).to_i

        event = EVENTS[:property_tracking]
        tracking_hash[udprn] = generic_event_count(event, table, property_id).to_i

        event = EVENTS[:interested_in_viewing]
        would_view_hash[udprn] = generic_event_count(event, table, property_id).to_i

        event = EVENTS[:interested_in_making_an_offer]
        would_make_an_offer_hash[udprn] = generic_event_count(event, table, property_id).to_i

        event = EVENTS[:requested_message]
        requested_message_hash[udprn] = generic_event_count(event, table, property_id).to_i

        event = EVENTS[:requested_viewing]
        requested_viewing_hash[udprn] = generic_event_count(event, table, property_id).to_i

        event = EVENTS[:requested_callback]
        requested_callback_hash[udprn] = generic_event_count(event, table, property_id).to_i

        event = EVENTS[:deleted]
        hidden_hash[udprn] = generic_event_count(event, table, property_id).to_i
      end

      ranking_stats[region_type][:property_search_ranking] = rank(save_search_hash, property_id)

      ranking_stats[region_type][:view_ranking] = rank(view_hash, property_id)

      ranking_stats[region_type][:total_enquiries_ranking] = rank(total_enquiry_hash, property_id)

      ranking_stats[region_type][:tracking_ranking] = rank(tracking_hash, property_id)
      
      ranking_stats[region_type][:would_view_ranking] = rank(would_view_hash, property_id)

      ranking_stats[region_type][:would_make_an_offer_ranking] = rank(would_make_an_offer_hash, property_id)

      ranking_stats[region_type][:message_requested_ranking] = rank(requested_message_hash, property_id)

      ranking_stats[region_type][:callback_requested_ranking] = rank(requested_callback_hash, property_id)

      ranking_stats[region_type][:requested_viewing_ranking] = rank(requested_viewing_hash, property_id)

      ranking_stats[region_type][:deleted_ranking] = rank(hidden_hash, property_id)

    end
    ranking_stats
  end


  ##### History of enquiries made by the user
  ##### Trackers::Buyer.new.history_enquiries(1)
  def history_enquiries(buyer_id, enquiry_type=nil, type_of_match=nil, property_status_type=nil, search_str=nil)
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    query = Event.where(buyer_id: buyer_id).where(event: events)
    query = query.where(type_of_match: TYPE_OF_MATCH[type_of_match]) if type_of_match
    query = query.where(event: EVENTS[enquiry_type.to_sym]) if enquiry_type
    query = query.search_address_and_agent_details(search_str) if search_str

    total_rows = query.order('created_at DESC').as_json

    total_rows.each do |each_row|
      new_row = {}
      new_row['received'] = each_row['created_at']
      new_row['type_of_enquiry'] = REVERSE_EVENTS[each_row['event']]
      new_row['time_of_event'] = each_row['created_at']
      new_row['buyer_id'] = each_row['buyer_id']
      new_row['udprn'] = each_row['udprn']
      details = PropertyDetails.details(each_row['udprn'])['_source']

      ### Skip this result
      (next if details['property_status_type'] != property_status_type) if property_status_type
      
      new_row['address'] = details['address']
      new_row['street_view_url'] = details['street_view_image_url']
      new_row['type_of_match'] = REVERSE_TYPE_OF_MATCH[each_row['type_of_match']]
      property_id = each_row['udprn']
      push_property_details_row(new_row, property_id)
      add_details_to_enquiry_row_buyer(new_row, property_id, each_row, nil)

      #### Parse scheduled viewing date. If a viewing has been requested by the buyer.
      #### TODO: Scope for optimization. Fetching isn't needed, its already present.
      responded_event = EVENTS[:viewing_stage]
      viewing_scheduled_event = Event.where(buyer_id: buyer_id).where(event: responded_event).where(udprn: property_id).order('created_at DESC').limit(1).first
      if viewing_scheduled_event
        message = viewing_scheduled_event.message
        new_row['scheduled_viewing_time'] = message['scheduled_viewing_time']
      end

      ### Price of the property
      details = PropertyDetails.details(each_row['udprn'])['_source']
      new_row['dream_price'] = details['dream_price']
      if details['property_status_type'] == 'Green' || details['property_status_type'] == 'Amber'
        PropertyDetailsRepo::PRICE_TYPES.each{|p| new_row[p] = details[p.to_s]  }
      elsif details['property_status_type'] == 'Red'
        new_row['last_sale_price'] = details['last_sale_price']
      end

      #### Udprn of properties nearby
      similar_udprns = PropertyDetails.similar_properties(each_row['udprn'])
      new_row['udprns'] = similar_udprns.select{ |t| t.to_i != each_row['udprn'] }

      #### Contact details of agents
      quote = Agents::Branches::AssignedAgents::Quote.where(property_id: each_row['udprn'].to_i).where(status: 3).first
      if quote
        agent = quote.agent
        new_row['assigned_agent_name'] = agent.name
        new_row['assigned_agent_email'] = agent.email
        new_row['assigned_agent_mobile'] = agent.mobile
        new_row['assigned_agent_office_number'] = agent.office_phone_number
        new_row['assigned_agent_image_url'] = agent.image_url
      else
        new_row['assigned_agent_name'] = nil
        new_row['assigned_agent_email'] = nil
        new_row['assigned_agent_mobile'] = nil
        new_row['assigned_agent_office_number'] = nil
        new_row['assigned_agent_image_url'] = nil
      end

      result.push(new_row)
    end

    result
  end


  def generic_event_count(event, table, property_id, type=:single)
    event_sql, count = nil
    if type == :single
      event_type = event
      count = Event.where(udprn: property_id).where(event: event_type).count
    else
      event_types = event.map { |e| EVENTS[e] }
      count = Event.where(udprn: property_id).where(event: event_types).count
    end
    # p "_#{event_sql}_#{property_id}_#{table}_#{event}_#{type}"
    count
  end

  def generic_event_count_buyer(event, table, property_id, buyer_id, type=:single)
    event_sql = nil
    if type == :single
      event_type = EVENTS[:event]
      count = Event.where(udprn: property_id).where(buyer_id: buyer_id).where(event: event).count
    else
      event_types = event.map { |e| EVENTS[e] }
      count = Event.where(udprn: property_id).where(buyer_id: buyer_id).where(event: event_types).count
    end
    # p "BUYER_#{event_sql}_#{property_id}_#{table}_#{event}_#{type}"
    count
  end

  def get_emails_of_buyer_trackers udprn
    Event.where(udprn: udprn).where(event: TRACKING_EVENTS.map { |e| EVENTS[e] }).select("buyer_name, buyer_email, created_at").as_json
  end

  def get_emails_of_buyer_enquiries udprn
    Event.where(udprn: udprn).where(event: ENQUIRY_EVENTS.map { |e| EVENTS[e] }).select("buyer_name, buyer_email, created_at").as_json
  end

  private

  def post_url(index, query = {}, type='_search', host='localhost')
    uri = URI.parse(URI.encode("http://#{host}:9200/#{index}/#{type}"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body, status
  end

  def rank(hash, key)
    sorted_values = hash.values.sort.reverse
    key_value = hash[key]
    index = sorted_values.index(key_value)
    run = rank = 0
    last_n = nil

    ranked = sorted_values.map do |n|
      run += 1
      next rank if n == last_n
      last_n = n
      rank += run
      run = 0
      rank
    end

    ranked[index.to_i].to_i
  end

end

#CREATE KEYSPACE Simple WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 3 };
=begin


#####################################################
#####################################################
#####################################################
#####################################################
DROP TABLE Simple.property_events_buyers_events;
DROP TABLE Simple.agents_buyer_events;
DROP TABLE Simple.timestamped_property_events;
DROP TABLE Simple.buyer_property_events;

CREATE TABLE Simple.property_events_buyers_events (
    stored_time timestamp,
    time_of_event timeuuid,
    date text,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    month int,
    PRIMARY KEY ((property_id), event, buyer_id, time_of_event)
);

CREATE TABLE Simple.agents_buyer_events (
    stored_time timestamp,
    time_of_event timeuuid,
    agent_id int,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((agent_id), buyer_id, event, time_of_event)
);

---SELECT * FROM Simple.timestamped_property_events WHERE agent_id = 23 AND buyer_id =  23 AND event= 3 ORDER BY buyer_id DESC, event DESC, time_of_event DESC LIMIT 1 ;

CREATE TABLE Simple.timestamped_property_events (
    stored_time timestamp,
    time_of_event timeuuid,
    agent_id int,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((agent_id), time_of_event, buyer_id)
);

CREATE TABLE Simple.buyer_property_events (
    stored_time timestamp,
    date text,
    buyer_id int,
    property_id text,
    status_id int,
    event int,
    message text,
    type_of_match int,
    month int,
    PRIMARY KEY ((buyer_id), event, property_id)
);


#####################################################
#####################################################

INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:01:01', now(), '2016-07-11', '10966139', 1, 1, 2, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:01:02', now(), '2016-07-11', '10966139', 1, 1, 3, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:02:03', now(), '2016-07-11', '10966139', 1, 1, 15, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:03:04', now(), '2016-07-11', '10966139', 1, 1, 16, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:04:05', now(), '2016-07-11', '10966139', 1, 1, 17, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:04:06', now(), '2016-07-11', '10966139', 1, 1, 18, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:05:07', now(), '2016-07-11', '10966139', 1, 1, 19, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:06:08', now(), '2016-07-11', '10966139', 1, 1, 23, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:07:09', now(), '2016-07-11', '10966139', 1, 1, 8, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:08:10', now(), '2016-07-11', '10966139', 1, 1, 9, NULL, 1, 7);
INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('2016-07-11 01:09:11', now(), '2016-07-11', '10966139', 1, 1, 10, NULL, 1, 7);


INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:01:01', now(), 1234, '10966139', 1, 1,  2, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:02:01', now(), 1234, '10966139', 1, 1,  3, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:03:01', now(), 1234, '10966139', 1, 1,  15, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:04:01', now(), 1234, '10966139', 1, 1, 16, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:05:01', now(), 1234, '10966139', 1, 1, 17, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:06:01', now(), 1234, '10966139', 1, 1, 18, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:07:01', now(), 1234, '10966139', 1, 1, 19, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:08:01', now(), 1234, '10966139', 1, 1, 23, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:09:01', now(), 1234, '10966139', 1, 1,  8, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:10:01', now(), 1234, '10966139', 1, 1,  9, NULL, 1);
INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:11:01', now(), 1234, '10966139', 1, 1, 10, NULL, 1);


INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:01:01', now(), 1234, '10966139', 1, 1,  2, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:02:01', now(), 1234, '10966139', 1, 1,  3, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:03:01', now(), 1234, '10966139', 1, 1,  15, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:04:01', now(), 1234, '10966139', 1, 1, 16, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:05:01', now(), 1234, '10966139', 1, 1, 17, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:06:01', now(), 1234, '10966139', 1, 1, 18, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:07:01', now(), 1234, '10966139', 1, 1, 19, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:08:01', now(), 1234, '10966139', 1, 1, 23, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:09:01', now(), 1234, '10966139', 1, 1,  8, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:10:01', now(), 1234, '10966139', 1, 1,  9, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:11:01', now(), 1234, '10966139', 1, 1, 10, NULL, 1);


INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:01:01', '2016-07-11', 1, '10966139', 1, 2 , NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:02:01', '2016-07-11', 1, '10966139', 1, 3 , NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:03:01', '2016-07-11', 1, '10966139', 1, 15 , NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:04:01', '2016-07-11', 1, '10966139', 1, 16 , NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:05:01', '2016-07-11', 1, '10966139', 1, 17 , NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:06:01', '2016-07-11', 1, '10966139', 1, 18 , NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:07:01', '2016-07-11', 1, '10966139', 1, 19 , NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:08:01', '2016-07-11', 1, '10966139', 1, 23, NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:09:01', '2016-07-11', 1, '10966139', 1, 8, NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:10:01', '2016-07-11', 1, '10966139', 1, 9, NULL, 1, 7);
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '2016-07-11 01:11:01', '2016-07-11', 1, '10966139', 1, 10, NULL, 1, 7);




=end
