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
    :requested_viewing
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
    :warm_property,
    :cold_property
  ]

  PAGE_SIZE = 10

  #### API Responses for tables

  def add_buyer_details(details, buyer_hash, is_premium=false, old_stats_flag=false)
    buyer_id = details[:buyer_id]
    buyer = buyer_hash[buyer_id]
    if buyer_id && buyer_hash[buyer_id]
      details['buyer_status'] = REVERSE_STATUS_TYPES[buyer_hash[buyer_id].status] rescue nil
      details['buyer_full_name'] = buyer_hash[buyer_id].first_name + ' ' + buyer_hash[buyer_id].last_name rescue ''
      details['buyer_image'] = buyer_hash[buyer_id].image_url
      details['buyer_email'] = buyer_hash[buyer_id].email
      details['buyer_mobile'] = buyer_hash[buyer_id].mobile
      details['chain_free'] = buyer_hash[buyer_id].chain_free
      details['buyer_funding'] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer_hash[buyer_id].funding] rescue nil
      details[:buyer_biggest_problems] = buyer[:biggest_problems]
      details[:buyer_property_types] = buyer[:property_types]
      details['buyer_buying_status'] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer_hash[buyer_id].buying_status] rescue nil
      details['buyer_budget_from'] = buyer_hash[buyer_id].budget_from
      details['buyer_budget_to'] = buyer_hash[buyer_id].budget_to
      details['views'] = buyer_view_ratio(buyer_id, details[:udprn], is_premium, old_stats_flag)
      details[:enquiries] = buyer_enquiry_ratio(buyer_id, details[:udprn], is_premium, old_stats_flag)
    else
      keys = [:buyer_status, :buyer_full_name, :buyer_image, :buyer_email, :buyer_mobile, :chain_free, :buyer_funding, :buyer_biggest_problems, :buyer_buying_status, :buyer_budget_from, :buyer_budget_to, :buyer_property_types, :views, :enquiries]
      keys.each { |key| details[key] = nil }
    end
  end

  def filtered_agent_query(agent_id: id, search_str: str=nil, last_time: time=nil, is_premium: premium=false, buyer_id: buyer=nil, type_of_match: match=nil, is_archived: archived=nil, closed: is_closed=nil)
    query = Event.where(agent_id: agent_id)
    parsed_last_time = Time.parse(last_time) if last_time
    query = query.where("created_at > ? ", parsed_last_time) if last_time
    query = query.unscope(where: :is_archived).where(is_archived: true) if is_archived.to_s == "true" && is_premium
    query = query.where(type_of_match: TYPE_OF_MATCH[type_of_match.to_s.downcase.to_sym]) if type_of_match
    query = query.where(buyer_id: buyer_id) if buyer_id && is_premium
    query = query.where(stage: [EVENTS[:closed_won_stage], EVENTS[:closed_lost_stage]]) if closed
    udprns = []
    if search_str && is_premium
      res = query.to_a
      res_udprns = res.map(&:udprn).uniq
      udprns = fetch_udprns(search_str, res_udprns)
      query = query.where(udprn: udprns) if search_str && is_premium
    end

    query
  end

  #### Push event based additional details to each property details
  ### Trackers::Buyer.new.push_events_details(PropertyDetails.details(10966139))
  def push_events_details(details, is_premium=false, old_stats_flag=false)
    new_row = {}
    new_row[:percent_completed] = PropertyService.new(details[:_source][:udprn]).compute_percent_completed({}, details[:_source] )
    new_row[:percent_completed] ||= nil

    new_row[:pictures] = details[:_source][:pictures]
    new_row[:pictures] = [] if details[:_source][:pictures].nil?
    image_url ||= "https://s3.ap-south-1.amazonaws.com/google-street-view-prophety/#{details[:_source][:udprn]}/fov_120_#{details[:_source][:udprn]}.jpg"
    new_row[:street_view_image_url] = image_url
    new_row[:status_last_updated] = details[:_source][:status_last_updated]
    new_row[:status_last_updated] = Time.parse(new_row[:status_last_updated]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:status_last_updated] 
    add_details_to_enquiry_row(new_row, details['_source'], is_premium, old_stats_flag)
    vendor_id = details[:_source][:vendor_id]

    lead = Agents::Branches::AssignedAgents::Lead.where(property_id: details[:_source][:udprn].to_i, vendor_id: vendor_id.to_i).last
    if lead
      new_row[:lead_expiry_time] = (lead.created_at + Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT).strftime("%Y-%m-%dT%H:%M:%SZ")
    else
      new_row[:lead_expiry_time] = nil
    end

    details['_source'].merge!(new_row)
    details['_source']
  end

  ### For every enquiry row, extract the info from details hash and merge it
  ### with new row
  def push_property_details(new_row, details)
    attrs = [ :address, :pictures, :street_view_image_url, :verification_status, :dream_price, :current_valuation, 
              :price, :status_last_updated, :property_type, :property_status_type, :beds, :baths, :receptions, 
              :details_completed, :date_added, :vendor_id, :vendor_first_name, :vendor_last_name, :vendor_image_url,
              :vendor_mobile_number, :street_view_image_url, :vendor_email ]
    new_row.merge!(details.slice(*attrs))
    if new_row[:street_view_image_url].nil?
      image_url = process_image(details) if Rails.env != 'test'
      image_url ||= "https://s3.ap-south-1.amazonaws.com/google-street-view-prophety/#{details[:udprn]}/fov_120_#{details['udprn']}.jpg"
      new_row[:street_view_image_url] = image_url
    end
    new_row[:pictures] = [] if new_row[:pictures].nil?
    new_row[:completed_status] = new_row[:details_completed]
    new_row[:listed_since] = new_row[:date_added]
    new_row[:agent_profile_image] = nil
    new_row[:advertised] = !PropertyAd.where(property_id: details[:udprn]).select(:id).limit(1).first.nil?
  end

  ### FIXME: 
  ### TODO: Initial version of rent assumes that rent and buy udprns are exclusive
  def add_details_to_enquiry_row(new_row, details, is_premium=false, old_stats_flag=false)
    table = ''
    #Rails.logger.info(details)
    property_id = details['udprn']

    if old_stats_flag && is_premium
      unarchived_property_stat = Events::EnquiryStatProperty.new(udprn: property_id)
      archived_property_stat = Events::ArchivedStat.new(udprn: property_id)

      ### Total Visits for premium users
      new_row['total_visits'] = archived_property_stat.views + unarchived_property_stat.views
      new_row['total_enquiries'] = archived_property_stat.enquiries + unarchived_property_stat.enquiries
      new_row['requested_viewing'] = archived_property_stat.specific_enquiry_count(:requested_viewing) + unarchived_property_stat.specific_enquiry_count(:requested_viewing)
      new_row['requested_message'] = archived_property_stat.specific_enquiry_count(:requested_message) + unarchived_property_stat.specific_enquiry_count(:requested_message)
      new_row['requested_callback'] = archived_property_stat.specific_enquiry_count(:requested_callback) + unarchived_property_stat.specific_enquiry_count(:requested_callback)
      new_row['interested_in_making_an_offer'] = archived_property_stat.specific_enquiry_count(:interested_in_making_an_offer) + unarchived_property_stat.specific_enquiry_count(:interested_in_making_an_offer)
      new_row['interested_in_viewing'] = archived_property_stat.specific_enquiry_count(:interested_in_viewing) + unarchived_property_stat.specific_enquiry_count(:interested_in_viewing)
      new_row['deleted'] = Events::IsDeleted.where(udprn: property_id).count
      new_row['offer_made_stage'] = Event.unscope(where: :is_developer).where(udprn: property_id).where(stage: EVENTS[:offer_made_stage]).count
      new_row['trackings'] = Events::Track.where(udprn: property_id).count 
    else
      property_stat = Events::EnquiryStatProperty.new(udprn: property_id)
      new_row['total_visits'] = property_stat.views
      new_row['total_enquiries'] = property_stat.enquiries
      new_row['requested_viewing'] = property_stat.specific_enquiry_count(:requested_viewing)
      new_row['requested_message'] = property_stat.specific_enquiry_count(:requested_message)
      new_row['requested_callback'] = property_stat.specific_enquiry_count(:requested_callback)
      new_row['interested_in_making_an_offer'] = property_stat.specific_enquiry_count(:interested_in_making_an_offer)
      new_row['interested_in_viewing'] = Event.where(udprn: property_id).where(stage: EVENTS[:interested_in_viewing]).count
      new_row['offer_made_stage'] = Event.where(udprn: property_id).where(stage: EVENTS[:offer_made_stage]).count

      ### Last sold property date
      sold_property = SoldProperty.where(udprn: property_id).select([:completion_date]).last
      if sold_property && sold_property.completion_date
        completion_date = sold_property.completion_date
        new_row['deleted'] = Events::IsDeleted.where('created_at > ?', completion_date).where(udprn: property_id).count
        new_row['trackings'] = Events::Track.where('created_at > ?', completion_date).where(udprn: property_id).count 
      else
        new_row['deleted'] = Events::IsDeleted.where(udprn: property_id).count
        new_row['trackings'] = Events::Track.where(udprn: property_id).count 
      end
    end

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
  def property_enquiry_details_buyer(agent_id, enquiry_type=nil, type_of_match=nil, qualifying_stage=nil, rating=nil, hash_str=nil, property_for='Sale', last_time=nil, is_premium=nil, buyer_id=nil, page_number=0, is_archived=nil, closed=nil, count=false, old_stats_flag=false)
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }
    ### Process filtered buyer_id only
    ### FIlter only the enquiries which are asked by the caller
    events = events.select{ |t| t == EVENTS[enquiry_type.to_sym] } if enquiry_type

    ### Filter only the type_of_match which are asked by the caller
    query = filtered_agent_query agent_id: agent_id, search_str: hash_str, last_time: last_time, is_premium: is_premium, buyer_id: buyer_id, type_of_match: type_of_match, is_archived: is_archived, closed: closed
    query = query.where(event: events) if enquiry_type
    query = query.where(stage: EVENTS[qualifying_stage.to_sym]) if qualifying_stage
    query = query.where(rating: EVENTS[rating.to_sym]) if rating
    
    if count && is_premium
      result = query.count
    elsif is_premium
      query = query.order('created_at DESC')
      total_rows = query.to_a
      result = process_enquiries_result(total_rows, agent_id, is_premium, old_stats_flag)
    else
      query = query.order('created_at DESC')
      total_rows = query.limit(PAGE_SIZE).offset(page_number.to_i*PAGE_SIZE)
      result = process_enquiries_result(total_rows, agent_id)
    end
    result
  end

  def process_enquiries_result(arr_rows=[], agent_id=nil, is_premium=false, old_stats_flag=false)
    buyer_ids = []
    result = []
    arr_rows.each_with_index do |each_row, index|
      new_row = {}
      new_row[:id] = each_row.id
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
      new_row[:stage] = REVERSE_EVENTS[each_row.stage]
      new_row[:hotness] = REVERSE_EVENTS[each_row.rating]
      new_row[:offer_date] = each_row.offer_date
      new_row[:offer_price] = each_row.offer_price

      ### If the property is closed won, include the details of the new buyer as well
      #Rails.logger.info("hello_#{each_row.udprn}")
      if each_row.stage == EVENTS[:closed_won_stage]
        sold_property = SoldProperty.where(udprn: each_row.udprn).last
        if sold_property
          new_row[:final_price] = sold_property.sale_price 
          new_buyer = PropertyBuyer.where(id: sold_property.buyer_id)
                                   .select([:id, :email, :first_name, :last_name, :mobile, :status, :chain_free, :funding, 
                                            :biggest_problems, :buying_status, :budget_to, :budget_from,
                                            :first_name, :last_name, :image_url, :property_types])
                                   .last
  
          if new_buyer
  
            new_buyer.as_json.each do |key, value|
              new_key = 'new_vendor_' + key.to_s
              new_row[new_key.to_sym] = value
            end
  
          end
          new_row[:actual_completion_date] = sold_property.completion_date
        end

      end
      new_row[:actual_completion_date] ||= nil
      new_row[:final_price] ||= nil
      new_row[:expected_completion_date] = each_row.expected_completion_date
      buyer_ids.push(each_row.buyer_id)
      result.push(new_row)
    end

    buyers = PropertyBuyer.where(id: buyer_ids).select([:id, :email, :first_name, :last_name, :mobile, :status, :chain_free, :funding, 
                                                        :biggest_problems, :buying_status, :budget_to, :budget_from,
                                                        :first_name, :last_name, :image_url, :property_types])
                          .order("position(id::text in '#{buyer_ids.join(',')}')")

    buyer_hash = {}

    buyers.each { |buyer| buyer_hash[buyer.id] = buyer }
    result.each { |row| add_buyer_details(row, buyer_hash, is_premium, old_stats_flag) }
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
             :verification_status, :vanity_url, :assigned_agent_id, :assigned_agent_image_url, :assigned_agent_mobile,
             :assigned_agent_email, :assigned_agent_title, :dependent_locality, :thoroughfare_description, :post_town, :agent_id,
             :beds, :baths, :receptions, :assigned_agent_first_name, :assigned_agent_last_name, :percent_completed]
    new_row.merge!(details.slice(*attrs))
    new_row[:image_url] = new_row[:street_view_image_url] || details[:pictures].first rescue nil
    if new_row[:image_url].nil?
      image_url = process_image(details) if Rails.env != 'test'
      image_url ||= "https://s3.ap-south-1.amazonaws.com/google-street-view-prophety/#{details['udprn']}/fov_120_#{details['udprn']}.jpg"
      new_row[:street_view_image_url] = image_url
    end
    new_row[:status] = new_row[:property_status_type]
    new_row[:percent_completed] ||= PropertyService.new(details[:udprn]).compute_percent_completed({}, details)
  end

  def add_details_to_enquiry_row_buyer(new_row, property_id, event_details, agent_id, property_for='Sale')
    #### Tracking property or not
    tracking_property_event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
    buyer_id = new_row[:buyer_id]
    qualifying_stage_query = Events::Stage
    tracking_query = nil
    tracking_result = Events::Track.where(buyer_id: buyer_id).where(type_of_tracking: tracking_property_event).where(udprn: property_id).select(:id).first
    new_row[:property_tracking] = (tracking_result.nil? ? false : true)
    new_row
  end

  def buyer_view_ratio(buyer_id, udprn, is_premium=false, old_stats_flag=false)
    property_views = buyer_views = nil

    if !is_premium
      buyer_views = Events::View.where(udprn: udprn).where(buyer_id: buyer_id).count
      property_views = Events::EnquiryStatProperty.new(udprn: udprn).views
    elsif old_stats_flag
      buyer_views = Events::View.where(udprn: udprn).unscope(where: :is_archived).where(buyer_id: buyer_id).count
      unarchived_property_views = Events::EnquiryStatProperty.new(udprn: udprn).views
      archived_property_views = Events::ArchivedStat.new(udprn: udprn).views
      property_views = unarchived_property_views + archived_property_views
    else
      buyer_views = Events::View.where(udprn: udprn).where(buyer_id: buyer_id).count
      property_views = Events::EnquiryStatProperty.new(udprn: udprn).views
    end

    buyer_views.to_s + '/' + property_views.to_s
  end

  def buyer_enquiry_ratio(buyer_id, udprn, is_premium=false, old_stats_flag=false)
    property_enquiries = buyer_enquiries = nil

    if !is_premium
      buyer_enquiries = Event.where(buyer_id: buyer_id).where(udprn: udprn).count
      property_enquiries = Events::EnquiryStatProperty.new(udprn: udprn).enquiries
    elsif old_stats_flag
      buyer_enquiries = Event.where(buyer_id: buyer_id).unscope(where: :is_archived).where(udprn: udprn).count
      unarchived_property_enquiries = Events::EnquiryStatProperty.new(udprn: udprn).enquiries
      archived_property_enquiries = Events::ArchivedStat.new(udprn: udprn).enquiries
      property_enquiries = unarchived_property_enquiries + archived_property_enquiries
    else
      buyer_enquiries = Event.where(buyer_id: buyer_id).where(udprn: udprn).count
      property_enquiries = Events::EnquiryStatProperty.new(udprn: udprn).enquiries
    end

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
    monthly_views = Events::View.where(udprn: property_id).group(:month).count

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
    results = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events_is_deleteds WHERE udprn=#{property_id} ").as_json
    aggregated_result[:deleted] =  results

    months = (1..12).to_a
    aggregated_result.each do |key, value|
      present_months = value.map { |e| e['month'].to_i }
      missing_months = months.select{ |t| !present_months.include?(t) }
      missing_months.each do |each_month|
        value.push({ 'month': each_month.to_s, count: 0.to_s })
      end
      aggregated_result[key] = value.sort_by{ |t| t['month'].to_i }
    end

    aggregated_result[:monthly_views] = months.map do |month|
      { month:  month.to_s, count: monthly_views[month].to_s }
    end
    aggregated_result
  end

  #### Track the number of searches of similar properties located around that property
  #### Trackers::Buyer.new.demand_info(10966139)
  #### TODO: Integrate it with rent
  def demand_info(udprn, property_for='Sale')
    details = PropertyDetails.details(udprn.to_i)['_source']
    #### Similar properties to the udprn
    #### TODO: Remove HACK FOR SOME Results to be shown
    # p details['hashes']

    ### Get the distribution of properties according to their property types which match
    ### exactly the buyer requirements
    klass = PropertyBuyer
    query = klass
    query = query.where('min_beds <= ?', details[:beds].to_i) if details[:beds]
    query = query.where('max_beds >= ?', details[:beds].to_i) if details[:beds]
    query = query.where('min_baths <= ?', details[:baths].to_i) if details[:baths]
    query = query.where('max_baths >= ?', details[:baths].to_i) if details[:baths]
    query = query.where('min_receptions <= ?', details[:receptions].to_i) if details[:receptions]
    query = query.where('max_receptions >= ?', details[:receptions].to_i) if details[:receptions]
    query = query.where(" ? = ANY(property_types)", details[:property_type]) if details[:property_type]
    query = query.where.not(status: nil)
    result_hash = query.group(:status).count
    
    distribution = {}
    PropertyBuyer::STATUS_HASH.each do |key, value|
      distribution[key] = result_hash[PropertyBuyer::REVERSE_STATUS_HASH[value]]
      distribution[key] ||= 0
    end
    distribution
  end

  #### Track the number of similar properties located around that property
  #### Trackers::Buyer.new.supply_info(10966139)
  def supply_info(udprn)
    details = PropertyDetails.details(udprn.to_i)['_source']
    #### Similar properties to the udprn
    #### TODO: Remove HACK FOR SOME Results to be shown
    default_search_params = {}
    default_search_params[:max_beds] = default_search_params[:min_beds] = details[:beds].to_i if details[:beds]
    default_search_params[:min_baths] = default_search_params[:max_baths] = details[:baths].to_i if details[:baths]
    default_search_params[:min_receptions] = default_search_params[:max_receptions] = details[:receptions].to_i if details[:receptions]
    default_search_params[:property_type] = details[:property_type] if details[:property_type]
    # p default_search_params

    ### analysis for each of the postcode type
    search_stats = {}
    street = :thoroughfare_description if details[:thoroughfare_description]
    street ||= :dependent_thoroughfare_description if details[:dependent_thoroughfare_description]
    
    [ :dependent_locality, street ].each do |region_type|
      ### Default search stats
      region = region_type
      if region_type == :thoroughfare_description || region_type == :dependent_thoroughfare_description
        region = :street
      else
        region = :locality
      end
      search_stats[region] = {}

      results = []

      if details[region_type] && default_search_params.keys.count > 0
        hash_str = MatrixViewService.form_hash_str(details, region_type)      
        search_params = default_search_params.clone
        search_params[:hash_str] = hash_str
        search_params[:hash_type] = region_type
        search_stats["#{region.to_s}_query_param".to_sym] = search_params.to_query
        # Rails.logger.info(search_params)
        page_counter = 1
        loop do
          search_params[:p] = page_counter
          api = PropertySearchApi.new(filtered_params: search_params)
          body = []
          body, status = api.filter
          break if body[:results].length == 0
          results += body[:results]
          page_counter += 1
        end
        ### Exclude the current udprn from the result
        results = results.select{|t| t[:udprn].to_i != udprn.to_i }
  
        results.each do |each_result|
          search_stats[region][each_result[:property_status_type]] ||= 0 if each_result[:property_status_type]
          search_stats[region][each_result[:property_status_type]] += 1 if each_result[:property_status_type]
        end
      end
      ['Green', 'Amber', 'Red'].each { |status| search_stats[region][status] ||= 0 }
      
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
      query = Event
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
    #event = EVENTS[:save_search_hash]

    query = Event
    buyer_ids = query.where(udprn: property_id).pluck(:buyer_id).uniq
    ### Buying status stats
    buying_status_distribution = PropertyBuyer.where(id: buyer_ids).where.not(buying_status: nil).group(:buying_status).count
    p buyer_ids
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
    funding_status_distribution = PropertyBuyer.where(id: buyer_ids).where.not(funding: nil).group(:funding).count
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
    biggest_problem_distribution = PropertyBuyer.where(id: buyer_ids).where.not(biggest_problems: nil).group(:biggest_problems).count
    total_count = biggest_problem_distribution.inject(0) do |result, (key, value)|
      result += (value*(key.length))
    end
    biggest_problem_stats = {}
    biggest_problem_distribution.each do |keys, value|
      keys.each do |key|
        biggest_problem_stats[key] = ((value.to_f/total_count.to_f)*100).round(2)
      end
    end
    PropertyBuyer::BIGGEST_PROBLEM_HASH.each { |k,v| biggest_problem_stats[k] = 0 unless biggest_problem_stats[k] }
    result_hash[:biggest_problem] = biggest_problem_stats

    ### Chain free stats
    chain_free_distribution = PropertyBuyer.where(id: buyer_ids).where.not(chain_free: nil).group(:chain_free).count
    total_count = chain_free_distribution.inject(0) do |result, (key, value)|
      result += value
    end
    chain_free_stats = {}
    chain_free_distribution.each do |key, value|
      chain_free_stats[key] = ((value.to_f/total_count.to_f)*100).round(2)
    end
    chain_free_stats[true] = 0 unless chain_free_stats[true]
    chain_free_stats[false] = 0 unless chain_free_stats[false]
    chain_free_stats['Yes'] = chain_free_stats[true]
    chain_free_stats['No'] = chain_free_stats[false]
    chain_free_stats.delete(true)
    chain_free_stats.delete(false)
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
    #stage_stats.merge!(count_stats)
    QUALIFYING_STAGE_EVENTS.each {|t| stage_stats[t] ||= 0 }

    aggregate_stats[:buyer_enquiry_distribution] = stage_stats

    rating_stats = {}

    HOTNESS_EVENTS.reverse.each {|t| rating_stats[t] ||= 0 }
    query = Event
    sum_count = 0
    stats = query.where(udprn: udprn).group(:rating).count
    stats.each do |key, value|
      rating_stats[REVERSE_EVENTS[key.to_i]] = value
      sum_count += value.to_i
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
      property_types: details['property_type']
    }

    ### analysis for each of the postcode type
    ranking_stats = {}
    [ :district, :sector, :unit ].each do |region_type|
      ### Default search stats
      ranking_stats[region_type] = {
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
      ##Rails.logger.info(search_params)
      api = PropertySearchApi.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_udprns
      udprns = []
      udprns = body.map(&:to_i)  if status.to_i == 200
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
        hidden_hash[udprn] = Events::IsDeleted.where(udprn: property_id).count
      end
      ranking_stats[region_type][:total_properties] = udprns.count
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
  def history_enquiries(buyer_id: id, enquiry_type: enquiry=nil, type_of_match: match=nil, property_status_type: status=nil, hash_str: str=nil, verification_status: is_verified=nil, last_time: time=nil, page_number: page=0, count: count_flag=false)
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }

    ### Dummy agent id to form the query. Is removed in the next line
    ### By Default enable search for all buyers
    query = filtered_agent_query agent_id: 1, last_time: last_time, buyer_id: buyer_id, type_of_match: type_of_match
    query = query.where(buyer_id: buyer_id)
    query = query.unscope(where: :agent_id)
    query = query.unscope(where: :is_archived)
    query = query.where(event: EVENTS[enquiry_type.to_sym]) if enquiry_type

    ### Search, verification status and property status type filters
    udprns = []
    if hash_str || property_status_type || verification_status
      res = query.to_a
      res_udprns = res.map(&:udprn).uniq
      udprns = fetch_udprns(hash_str, res_udprns, property_status_type, verification_status)
      query = query.where(udprn: udprns)
    end

    total_rows = []
    if count
      total_rows = query.count
    else
      query = query.order('created_at DESC')
      query = query.to_a
      total_rows = query
      #total_rows = query.limit(PAGE_SIZE).offset(page_number.to_i*PAGE_SIZE)
      total_rows = process_enquiries_result(total_rows)
    end
    total_rows
  end

  def fetch_udprns(hash_str, udprns=[], property_status_type=nil, verification_status=nil)
    hash_val = { hash_str: hash_str }
    PropertySearchApi.construct_hash_from_hash_str(hash_val)
    if hash_val[:udprn]
      [hash_val[:udprn]]      
    elsif !udprns.empty?
      hash_val[:udprns] = udprns.map(&:to_s).join(',')
      hash_val[:hash_str] = hash_str
      hash_val[:property_status_type] = property_status_type if property_status_type
      hash_val[:verification_status] = verification_status if verification_status
      hash_val[:hash_type] = 'Text'
      api = PropertySearchApi.new(filtered_params: hash_val)
      api.modify_filtered_params
      api.apply_filters
      api.increase_size_filter
      udprns, status = api.fetch_udprns 
      
      ### If the status is 200
      if status.to_i == 200
        udprns.map(&:to_i)
      else
        []
      end

    else
      hash_val[:hash_type] = 'Text'
      #hash_val.delete(:hash_str)
      hash_val[:property_status_type] = property_status_type if property_status_type
      hash_val[:verification_status] = verification_status if verification_status
      api = PropertySearchApi.new(filtered_params: hash_val)
      api.modify_filtered_params
      api.apply_filters
      api.increase_size_filter
      udprns, status = api.fetch_udprns 
      if status.to_i == 200
        udprns.map(&:to_i)
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

