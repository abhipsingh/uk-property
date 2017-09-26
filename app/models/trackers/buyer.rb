class Trackers::Buyer
  include EventsHelper

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
    'Red'   => 3,
    'Rent'  => 4
  }

  PROPERTY_TYPES = {
    'Sale' => 1,
    'Rent' => 2
  }

  LISTING_TYPES = {
    'Normal' => 1,
    'Premium' => 2,
    'Featured' => 3
  }

  SERVICES = {
    'Sale' => 1,
    'Rent' => 2
  }

  REVERSE_LISTING_TYPES = LISTING_TYPES.invert

  REVERSE_STATUS_TYPES = PROPERTY_STATUS_TYPES.invert

  REVERSE_TYPE_OF_MATCH = TYPE_OF_MATCH.invert

  REVERSE_EVENTS = EVENTS.invert

  CONFIDENCE_ROWS = (1..5).to_a

  REVERSE_SERVICES = SERVICES.invert

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

  SUCCESSFUL_SEQUENCE_STAGES = [
    :qualifying_stage,
    :interested_in_viewing,
    :negotiating_stage,
    :conveyance_stage,
    :offer_made_stage,
    :offer_accepted_stage,
    :closed_won_stage,
    :contract_exchange_stage,
    :completion_stage,
    :sold
  ]

  UNSUCCESSFUL_SEQUENCE_STAGES = [
    :qualifying_stage,
    :interested_in_viewing,
    :negotiating_stage,
    :conveyance_stage,
    :offer_made_stage,
    :closed_lost_stage
  ]

  HOTNESS_EVENTS = [
    :hot_property,
    :cold_property,
    :warm_property
  ]

  PAGE_SIZE = 20

  #### API Responses for tables

  def add_buyer_details(details, buyer_hash)
    if details['buyer_id']
      details['buyer_status'] = REVERSE_STATUS_TYPES[buyer_hash[details['buyer_id']]['status']] rescue nil
      details['buyer_full_name'] = buyer_hash[details['buyer_id']]['name']
      details['buyer_image'] = buyer_hash[details['buyer_id']]['image_url']
      details['buyer_email'] = buyer_hash[details['buyer_id']]['email']
      details['buyer_mobile'] = buyer_hash[details['buyer_id']]['mobile']
      details['chain_free'] = buyer_hash[details['buyer_id']]['chain_free']
      details['buyer_funding'] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer_hash[details['buyer_id']]['funding']] rescue nil
      details['buyer_biggest_problem'] = PropertyBuyer::REVERSE_BIGGEST_PROBLEM_HASH[buyer_hash[details['buyer_id']]['biggest_problem']] rescue nil
      details['buyer_buying_status'] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer_hash[details['buyer_id']]['buying_status']] rescue nil
      details['buyer_budget_from'] = buyer_hash[details['buyer_id']]['budget_from']
      details['buyer_budget_to'] = buyer_hash[details['buyer_id']]['budget_to']
      details['views'] = buyer_view_ratio(details['buyer_id'], details['udprn'])
      details[:enquiries] = buyer_enquiry_ratio(details['buyer_id'], details['udprn'])
    else
      details['buyer_status'] = nil
      details['buyer_full_name'] = nil
      details['buyer_image'] = nil
      details['buyer_email'] = nil
      details['buyer_mobile'] = nil
      details['chain_free'] = nil
      details['buyer_funding'] = nil
      details['buyer_biggest_problem'] = nil
      details['buyer_buying_status'] = nil
      details['buyer_budget_from'] = nil
      details['buyer_budget_to'] = nil
      details['views'] = nil
      details[:enquiries] = nil
    end
  end

  #### Agent enquiries latest implementation
  #### Trackers::Buyer.new.search_latest_enquiries(1234)
  ### Per property
  def search_latest_enquiries(agent_id, property_status_type=nil, verification_status=nil, ads=nil, search_str=nil, property_for='Sale', last_time=nil, is_premium=false, buyer_id=nil, page_number=0, is_archived=nil)
    query = filtered_agent_query agent_id: agent_id, search_str: search_str, last_time: last_time, is_premium: is_premium, buyer_id: buyer_id, archived: is_archived
    property_ids = query.order('created_at DESC').limit(PAGE_SIZE).offset(page_number*PAGE_SIZE).select(:udprn).pluck(:udprn).uniq
    response = property_ids.map { |e| Trackers::Buyer.new.property_and_enquiry_details(agent_id.to_i, e, property_status_type, verification_status, ads) }.compact
  end

  def filtered_agent_query(agent_id: id, search_str: str=nil, last_time: time=nil, is_premium: premium=false, buyer_id: buyer=nil, type_of_match: match=nil, is_archived: archived=nil)
    query = Event.where(agent_id: agent_id)
    parsed_last_time = Time.parse(last_time) if last_time
    query = query.where("created_at > ? ", parsed_last_time) if last_time
    query = query.unscope(where: :is_archived).where(is_archived: true) if is_archived == true
    query = query.where(type_of_match: TYPE_OF_MATCH[type_of_match.to_s.downcase.to_sym]) if type_of_match
    query = query.where(buyer_id: buyer_id) if buyer_id && is_premium
    udprns = fetch_udprns(search_str) if search_str && is_premium
    query = query.where(udprn: udprns) if search_str && is_premium
    query
  end

  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ########## Property level enquiries ###########################

  ##### To mock this in the console try 
  ##### Trackers::Buyer.new.property_and_enquiry_details(1234, '10966139')
  def property_and_enquiry_details(agent_id, property_id, property_status_type=nil, verification_status=nil, ads=nil, property_for='Sale')
    details = PropertyDetails.details(property_id)['_source']
    # details = {}
    new_row = {}

    property_enquiry_details(new_row, property_id, details, property_for)

    return nil if property_status_type && property_status_type != new_row[:property_status_type]
    return nil if !verification_status.nil? && verification_status.to_s != new_row[:verification_status].to_s
    return nil if !ads.nil? && ads.to_s != new_row[:advertised].to_s

    push_agent_details(new_row, agent_id)

    new_row
  end

  #### Push event based additional details to each property details
  ### Trackers::Buyer.new.push_events_details(PropertyDetails.details(10966139))
  def push_events_details(details, property_for='Sale')
    new_row = {}
    add_details_to_enquiry_row(new_row, details['_source'], property_for)
    details['_source'].merge!(new_row)
    details
  end

  #### Push agent specific details
  def push_agent_details(new_row, agent_id)
    keys = [:name, :email, :mobile, :office_phone_number, :image_url]
    agents = Agents::Branches::AssignedAgent.where(id: agent_id).select(keys).as_json
    agents.each { |e| keys.each { |k| new_row[k] = e[k.to_s] } }
  end

  def property_enquiry_details(new_row, property_id, details, property_for='Sale')
    push_property_details(new_row, details)
    add_details_to_enquiry_row(new_row, details, property_for)
  end

  ### For every enquiry row, extract the info from details hash and merge it
  ### with new row
  def push_property_details(new_row, details)
    attrs = [ :address, :pictures, :street_view_image_url, :verification_status, :dream_price, :current_valuation, 
              :price, :status_last_updated, :property_type, :property_status_type, :beds, :baths, :receptions, 
              :details_completed, :date_added ]
    new_row.merge!(details.slice(*attrs))
    new_row[:image_url] = details['pictures'] ? details['pictures'][0] : "Image not available"
    if new_row[:image_url].nil?
      image_url = process_image(details) if Rails.env != 'test'
      image_url ||= "https://s3.ap-south-1.amazonaws.com/google-street-view-prophety/#{details['udprn']}/fov_120_#{details['udprn']}.jpg"
      new_row[:image_url] = image_url
    end
    
    new_row[:completed_status] = new_row[:details_completed]
    new_row[:listed_since] = new_row[:date_added]
    new_row[:agent_profile_image] = nil
    new_row[:advertised] = !PropertyAd.where(property_id: details[:udprn]).select(:id).limit(1).first.nil?
  end

  ### FIXME: 
  ### TODO: Initial version of rent assumes that rent and buy udprns are exclusive
  def add_details_to_enquiry_row(new_row, details, property_for='Sale')
    table = ''
    property_id = details['udprn']
    property_stat = Events::EnquiryStatProperty.new(udprn: property_id)
    ### Extra keys to be added
    ### TODO: Might have to unscope depending on the requirements
    new_row['total_visits'] = property_stat.views
    new_row['total_enquiries'] = property_stat.enquiries
    new_row['trackings'] = Events::Track.where(udprn: property_id).count 
    new_row['requested_viewing'] = property_stat.specific_enquiry_count(:requested_viewing)
    new_row['offer_made_stage'] = Event.where(udprn: property_id).where(stage: EVENTS[:offer_made_stage]).count
    new_row['requested_message'] = property_stat.specific_enquiry_count(:requested_message)
    new_row['requested_callback'] = property_stat.specific_enquiry_count(:requested_callback)
    new_row['interested_in_making_an_offer'] = property_stat.specific_enquiry_count(:interested_in_making_an_offer)
    new_row['interested_in_viewing'] = Event.where(udprn: property_id).where(stage: EVENTS[:interested_in_viewing]).count
    # new_row['deleted'] = generic_event_count(EVENTS[:deleted], table, property_id, :single, property_for)
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
  def property_enquiry_details_buyer(agent_id, enquiry_type=nil, type_of_match=nil, qualifying_stage=nil, rating=nil, hash_str=nil, property_for='Sale', last_time=nil, is_premium=nil, buyer_id=nil, page_number=0, is_archived=nil)
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    ### Process filtered buyer_id only
    ### FIlter only the enquiries which are asked by the caller
    events = events.select{ |t| t == EVENTS[enquiry_type.to_sym] } if enquiry_type

    ### Filter only the type_of_match which are asked by the caller
    query = filtered_agent_query agent_id: agent_id, search_str: hash_str, last_time: last_time, is_premium: is_premium, buyer_id: buyer_id, type_of_match: type_of_match, is_archived: is_archived
    query = query.where(event: events) if enquiry_type
    query = query.where(stage: EVENTS[qualifying_stage]) if qualifying_stage
    query = query.where(rating: EVENTS[rating]) if rating
    query = query.order('created_at DESC')
    total_rows = query.limit(PAGE_SIZE).offset(page_number*PAGE_SIZE)
    result = process_enquiries_result(total_rows, agent_id)
    result
  end

  def process_enquiries_result(arr_rows=[], agent_id=nil)
    buyer_ids = []
    result = []
    arr_rows.each_with_index do |each_row, index|
      new_row = {}
      new_row[:udprn] = each_row.udprn
      new_row[:received] = each_row.created_at
      new_row[:type_of_enquiry] = REVERSE_EVENTS[each_row.event]
      new_row[:time_of_event] = each_row.created_at.to_time.to_s
      new_row[:buyer_id] = each_row.buyer_id
      new_row[:type_of_match] = REVERSE_TYPE_OF_MATCH[each_row.type_of_match]
      new_row[:scheduled_visit_time] = each_row.scheduled_visit_time
      property_id = each_row.udprn
      push_property_details_row(new_row, property_id)
      add_details_to_enquiry_row_buyer(new_row, property_id, each_row, agent_id, 'Sale')
      new_row[:stage] = REVERSE_EVENTS[each_row.event]
      new_row[:hotness] = REVERSE_EVENTS[each_row.stage]
      buyer_ids.push(each_row.buyer_id)
      result.push(new_row)
    end

    buyers = PropertyBuyer.where(id: buyer_ids).select([:id, :email, :full_name, :mobile, :status, :chain_free, :funding, 
                                                        :biggest_problem, :buying_status, :budget_to, :budget_from ])
                          .order("position(id::text in '#{buyer_ids.join(',')}')")

    buyer_hash = {}

    buyers.each { |buyer| buyer_hash[buyer.id] = buyer }
    result.each { |row| add_buyer_details(row, buyer_hash) }
    result
  end

  def push_property_details_row(new_row, property_id)
    details =  PropertyDetails.details(property_id)['_source']
    push_property_enquiry_details_buyer(new_row, details)
  end

  ### For every enquiry row, extract the info from details hash and merge it
  ### with new row
  def push_property_enquiry_details_buyer(new_row, details)
    attrs = [:address, :price, :dream_price, :current_valuation, :pictures, :street_view_image_url, :sale_prices, :property_status_type, 
             :verification_status]
    new_row.merge!(details.slice(*attrs))
    new_row[:image_url] = new_row[:street_view_image_url] || details[:pictures].first rescue nil
    if new_row[:image_url].nil?
      # image_url = process_image(details) if Rails.env != 'test'
      # image_url ||= "https://s3.ap-south-1.amazonaws.com/google-street-view-prophety/#{details['udprn']}/fov_120_#{details['udprn']}.jpg"
      # new_row[:image_url] = image_url
    end
    new_row[:status] = new_row[:property_status_type]
  end

  def add_details_to_enquiry_row_buyer(new_row, property_id, event_details, agent_id, property_for='Sale')
    #### Tracking property or not
    tracking_property_event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
    buyer_id = event_details['buyer_id']
    qualifying_stage_query = Events::Stage
    tracking_query = nil
    tracking_result = Events::Track.where(buyer_id: buyer_id).where(type_of_tracking: tracking_property_event).where(udprn: property_id).select(:id).first
    new_row[:property_tracking] = (tracking_result.nil? == 0 ? false : true)
    new_row
  end

  def buyer_view_ratio(buyer_id, udprn)
    buyer_views = Events::EnquiryStatBuyer.new(buyer_id: buyer_id).views
    property_views = Events::EnquiryStatProperty.new(udprn: udprn).views
    buyer_views.to_s + '/' + property_views.to_s
  end

  def buyer_enquiry_ratio(buyer_id, udprn)
    buyer_enquiries = Events::EnquiryStatBuyer.new(buyer_id: buyer_id).enquiries
    property_enquiries = Events::EnquiryStatProperty.new(udprn: udprn).enquiries
    buyer_enquiries.to_s + '/' + property_enquiries.to_s
  end

  #### Buyer interest details. To test it, just run the following in the irb
  #### Trackers::Buyer.new.interest_info(10966139)
  #### TODO: Fixme: When a udprn can be rent and the buy or vice-versa, it needs to be segregated
  #### And over multiple lifetimes
  def interest_info(udprn)
    property_for = nil
    aggregated_result = {}
    property_id = udprn.to_i
    current_month = Date.today.month

    event = EVENTS[:viewed]
    monthly_views = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event} AND udprn=#{property_id} ").as_json
    aggregated_result[:monthly_views] =  monthly_views

    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    monthly_enquiries = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event IN (#{events.join(',')})  AND udprn=#{property_id} ").as_json
    aggregated_result[:enquiries] =  monthly_enquiries
    
    event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
    monthly_property_tracking = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events_tracks WHERE type_of_tracking=#{event}  AND udprn=#{property_id} ").as_json
    aggregated_result[:property_tracking] =  monthly_property_tracking

    ENQUIRY_EVENTS.each do |event|
      result = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{EVENTS[event]}  AND udprn=#{property_id} ").as_json
      aggregated_result[event] =  result
    end

    event = EVENTS[:deleted]
    results = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{event}  AND udprn=#{property_id} ").as_json
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
  #### TODO: Integrate it with rent
  def demand_info(udprn, property_for='Sale')
    details = PropertyDetails.details(udprn.to_i)['_source']
    Rails.logger.info(details)
    table = ''
    
    #### Similar properties to the udprn
    #### TODO: Remove HACK FOR SOME Results to be shown
    # p details['hashes']
    default_search_params = {
      min_beds: details['beds'].to_i - 2,
      max_beds: details['beds'].to_i + 2,
      min_baths: details['baths'].to_i - 2 ,
      max_baths: details['baths'].to_i + 2,
      min_receptions: details['receptions'].to_i - 2,
      max_receptions: details['receptions'].to_i + 2,
      property_status_types: details['property_status_type']
    }
    # p default_search_params

    ### analysis for each of the postcode type
    search_stats = {}
    [ :district, :sector, :unit ].each do |region_type|
      ### Default search stats
      search_stats[region_type] = { perfect_matches: 0, potential_matches: 0, total_matches: 0 }

      search_params = default_search_params.clone
      search_params[region_type] = details[region_type.to_s]
      # Rails.logger.info(search_params)
      search_stats[region_type][:value] = details[region_type.to_s] ### Populate the value of sector, district and unit
      api = PropertySearchApi.new(filtered_params: search_params)
      api.apply_filters
      udprns = []
      udprns, status = api.fetch_udprns
      udprns = udprns.map(&:to_i) if status.to_i == 200
      ### Exclude the current udprn from the result
      udprns = udprns - [ udprn.to_i ]
      ### Accumulate data for each udprn
      type_of_match = TYPE_OF_MATCH[:perfect]
      event = EVENTS[:save_search_hash]

      query = Event

      search_stats[region_type][:perfect_matches] = Event.unscope(where: :is_archived).where(udprn: udprns).where(event: event).where(type_of_match: type_of_match).count

      type_of_match = TYPE_OF_MATCH[:potential]
      search_stats[region_type][:potential_matches] = Event.unscope(where: :is_archived).where(udprn: udprns).where(event: event).where(type_of_match: type_of_match).count

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
      property_status_types: details['property_status_type']
    }

    ### analysis for each of the postcode type
    search_stats = {}
    [ :district, :sector, :unit ].each do |region_type|
      ### Default search stats
      search_stats[region_type] = { green: 0, amber: 0, red: 0 }

      search_params = default_search_params.clone
      search_params[region_type] = details[region_type.to_s]
      search_stats[region_type][:value] = details[region_type.to_s] ### Populate the value of sector, district and unit
      api = PropertySearchApi.new(filtered_params: search_params)
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
  def buyer_intent_info(udprn, property_for='Sale')
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
      api = PropertySearchApi.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      udprns = []
      if status.to_i == 200
        udprns = body.map { |e| e['udprn'] }
      end

      ### Exclude the current udprn from the result
      udprns = udprns - [ udprn.to_s ]
      # p udprns
      ### Accumulate buyer_id for each udprn
      buyer_ids = []
      event = EVENTS[:save_search_hash]
      query = nil
      if property_for == 'Sale'
        query = Event.where.not(property_status_type: PROPERTY_STATUS_TYPES['Rent'])
      else
        query = Event.where(property_status_type: PROPERTY_STATUS_TYPES['Rent'])
      end
      buyer_ids = query.where(event: event).where(udprn: udprns).pluck(:buyer_id).uniq

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
  #### TODO: This has lot of attributes relevant for Sale
  #### Have to fork a new method for Rent
  def buyer_profile_stats(udprn, property_for='Sale')
    result_hash = {}
    property_id = udprn.to_i
    details = PropertyDetails.details(udprn.to_i)['_source'] rescue {}
    event = EVENTS[:save_search_hash]

    query = nil
    if property_for == 'Sale'
      query = Event.where.not(property_status_type: PROPERTY_STATUS_TYPES['Rent'])
    else
      query = Event.where(property_status_type: PROPERTY_STATUS_TYPES['Rent'])
    end

    buyer_ids = query.where(event: event).where(udprn: property_id).where(type_of_match: 1).pluck(:buyer_id).uniq

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
  def agent_stage_and_rating_stats(udprn, property_for='Sale')
    aggregate_stats = {}
    property_id = udprn.to_i
    query = Event
    stats = query.where(udprn: udprn).group(:stage).count
    stage_stats = {}

    sum_count = 0
    stats.each do |key, value|
      stage_stats[REVERSE_EVENTS[key.to_i]] = value
      sum_count += value.to_i
    end

    stage_stats.each do |key, value|
      stage_stats[key] = ((value.to_f/sum_count)*100).round(2)
      stage_stats[key.to_s+'_count'] = value
    end

    aggregate_stats[:buyer_enquiry_distribution] = stage_stats

    rating_stats = {}

    query = nil
    if property_for == 'Sale'
      query = Event.where.not(property_status_type: PROPERTY_STATUS_TYPES['Rent'])
    else
      query = Event.where(property_status_type: PROPERTY_STATUS_TYPES['Rent'])
    end

    sum_count = 0
    stats = query.where(udprn: udprn).where("created_at > ?", 5.months.ago).group(:rating).count
    stats.each do |key, value|
      rating_stats[REVERSE_EVENTS[key.to_i]] = value
      sum_count += value.to_i
    end

    stage_stats.each do |key, value|
      rating_stats[key] = ((value.to_f/sum_count)*100).round(2)
      rating_stats[key.to_s+'_count'] = value
    end

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
      property_status_types: details['property_status_type']
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
      api = PropertySearchApi.new(filtered_params: search_params)
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
        property_stat = Events::EnquiryStatProperty.new(udprn: udprn)
        view_hash[udprn] = property_stat.views
        total_enquiry_hash[udprn] = property_stat.enquiries

        event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
        tracking_hash[udprn] = Events::Track.where(type_of_tracking: event).where(udprn: property_id).count
        would_view_hash[udprn] = property_stat.specific_enquiry_count(:interested_in_viewing)
        would_make_an_offer_hash[udprn] = property_stat.specific_enquiry_count(:interested_in_making_an_offer)
        requested_message_hash[udprn] = property_stat.specific_enquiry_count(:requested_message)
        requested_viewing_hash[udprn] = property_stat.specific_enquiry_count(:requested_viewing)
        requested_callback_hash[udprn] = property_stat.specific_enquiry_count(:requested_callback)
        # event = EVENTS[:deleted]
        # hidden_hash[udprn] = generic_event_count(event, table, property_id).to_i
      end

      ranking_stats[region_type][:view_ranking] = rank(view_hash, property_id)
      ranking_stats[region_type][:total_enquiries_ranking] = rank(total_enquiry_hash, property_id)
      ranking_stats[region_type][:tracking_ranking] = rank(tracking_hash, property_id)
      ranking_stats[region_type][:would_view_ranking] = rank(would_view_hash, property_id)
      ranking_stats[region_type][:would_make_an_offer_ranking] = rank(would_make_an_offer_hash, property_id)
      ranking_stats[region_type][:message_requested_ranking] = rank(requested_message_hash, property_id)
      ranking_stats[region_type][:callback_requested_ranking] = rank(requested_callback_hash, property_id)
      ranking_stats[region_type][:requested_viewing_ranking] = rank(requested_viewing_hash, property_id)
      # ranking_stats[region_type][:deleted_ranking] = rank(hidden_hash, property_id)
    end
    ranking_stats
  end


  ##### History of enquiries made by the user
  ##### Trackers::Buyer.new.history_enquiries(1)
  def history_enquiries(buyer_id: id, enquiry_type: enquiry=nil, type_of_match: match=nil, property_status_type: status=nil, search_str: str=nil, verified: is_verified=nil, last_time: time=nil, page_number=0)
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }

    ### Dummy agent id to form the query. Is removed in the next line
    ### By Default enable search for all buyers
    query = filtered_agent_query agent_id: 1, search_str: search_str, last_time: last_time, is_premium: true, buyer_id: buyer_id, type_of_match: type_of_match
    query = query.unscope(where: :agent_id)
    query = query.unscope(where: :is_archived)
    query = query.where(event: EVENTS[enquiry_type.to_sym]) if enquiry_type
    query = query.order('created_at DESC')
    total_rows = query.limit(PAGE_SIZE).offset(page_number*PAGE_SIZE)
    total_rows = process_enquiries_result(total_rows)
    total_rows = total_rows.map do |each_row|
      (next if each_row['property_status_type'] != property_status_type) if property_status_type
      (next if each_row['verification_status'] != verified) if verified
      each_row[:views] = buyer_view_ratio(each_row['buyer_id'], each_row['udprn'])
      each_row[:enquiries] = buyer_enquiry_ratio(each_row['buyer_id'], each_row['udprn'])
      each_row
    end

    total_rows
  end

  def fetch_udprns(hash_str)
    hash_val = { hash_str: hash_str }
    PropertySearchApi.construct_hash_from_hash_str(hash_val)
    if hash_val[:udprn]
      [hash_val[:udprn]]      
    else
      hash_val.delete(:hash_str)
      api = PropertySearchApi.new(filtered_params: hash_val)
      api.apply_filters
      udprns, status = api.fetch_udprns
      if status.to_i == 200
        udprns
      else
        []
      end
    end
  end

  private

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

