class EventService
  include EventsHelper

  attr_accessor :udprn, :agent_id, :vendor_id, :service, :buyer_id, :details, :is_premium, :qualifying_stage, :rating, :archived,
                :closed, :count, :profile_type, :old_stats_flag

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
    dream_price_change: 33,
    requested_floorplan: 34
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

  SERVICES = {
    'Sale' => 1,
    'Rent' => 2
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

  REVERSE_LISTING_TYPES = LISTING_TYPES.invert

  REVERSE_STATUS_TYPES = PROPERTY_STATUS_TYPES.invert

  REVERSE_TYPE_OF_MATCH = TYPE_OF_MATCH.invert

  REVERSE_EVENTS = EVENTS.invert

  REVERSE_SERVICES = SERVICES.invert

  CONFIDENCE_ROWS = (1..5).to_a

  ENQUIRY_EVENTS = [
    :interested_in_viewing,
    :interested_in_making_an_offer,
    :requested_message,
    :requested_callback,
    :requested_viewing,
    :viewing_stage,
    :requested_floorplan
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

  ENQUIRY_PAGE_SIZE = 10


  def initialize(udprn: udprn=nil, agent_id: agent_id=nil, vendor_id: vendor_id=nil, buyer_id: buyer_id=nil, last_time: time=nil, qualifying_stage: stage=nil, rating: enquiry_rating=nil, archived: is_archived=nil, is_premium: premium=nil, closed: is_closed=nil, count: count_flag=false, profile: profile_type=nil, old_stats_flag: old_flag=false)
    @udprn = udprn.to_i
    @agent_id = agent_id
    @vendor_id = vendor_id
    @buyer_id = buyer_id
    @last_time = last_time
    @qualifying_stage = qualifying_stage
    @rating = rating
    @archived = archived
    @is_premium = is_premium
    @closed = closed
    @details = PropertyDetails.details(@udprn.to_i)['_source'] if @udprn
    @count = count
    @profile_type = profile
    @old_stats_flag = old_stats_flag
  end

  def property_specific_enquiries(page)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    query = Event.where(udprn: @udprn)

    ### Last time filter
    query = query.where("created_at > ?", @last_time) if @last_time

    ### Stage filter
    query = query.where(stage: Event::EVENTS[@qualifying_stage]) if @qualifying_stage

    ### Rating filter
    query = query.where(rating: Event::EVENTS[@rating]) if @rating

    ### buyer id filter
    query = query.where(buyer_id: @buyer_id) if @buyer_id && @is_premium

    ### closed won or lost filter
    query = query.where(stage: [Event::EVENTS[:closed_won_stage], Event::EVENTS[:closed_lost_stage]]) if @closed

    ### Archived filter
    archived_cond = ((@archived || @old_stats_flag) && @is_premium)
    query = query.unscope(where: :is_archived) if archived_cond

    query

  end

  def order_and_paginate(query, page)
    if @is_premium
      query = query.order('created_at DESC').limit(ENQUIRY_PAGE_SIZE)
                   .offset(ENQUIRY_PAGE_SIZE*page)
    else
      query = query.order('created_at DESC').limit(ENQUIRY_PAGE_SIZE)
                   .offset(ENQUIRY_PAGE_SIZE*page)
    end
    query
  end


  def property_specific_enquiry_details(page)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    enquiries = property_specific_enquiries(page)
    if @count && @is_premium
      enquiries.count  
    else
      enquiries = order_and_paginate(enquiries, page)
      Rails.logger.info("Sql query #{enquiries.to_sql}")
      enquiry_details = enquiries.map { |enquiry| construct_enquiry_detail(enquiry) }

      if @profile_type == 'Agents::Branches::AssignedAgent'
        buyer_ids = enquiry_details.map { |enquiry| enquiry[:buyer_id] }
        buyers = PropertyBuyer.where(id: buyer_ids.flatten).select([:id, :first_name, :last_name, :email, :mobile, :status, :chain_free, :funding, :biggest_problems, :buying_status, :budget_to, :budget_from, :image_url, :property_types]).order("position(id::text in '#{buyer_ids.join(',')}')")
        buyer_hash = {}
        buyers.each { |buyer| buyer_hash[buyer.id] = buyer }
        enquiry_details.each { |row| add_buyer_details(row, buyer_hash) }
      end
      enquiry_details

    end
  end

  def construct_enquiry_detail(enquiry)
    each_row = enquiry
    new_row = {}
    new_row[:id] = each_row.id
    new_row[:received] = each_row.created_at

    ### Added new condition that when property is verified and details completed
    #if @details[:verification_status].to_s == 'true' &&  @details[:details_completed].to_s == 'true'
    if true
      new_row[:id] = each_row.id
      new_row[:type_of_enquiry] = REVERSE_EVENTS[each_row.event]
      new_row[:buyer_id] = each_row.buyer_id
      new_row[:property_tracking] = total_trackings
      new_row[:views] = view_ratio(each_row.buyer_id)
      new_row[:enquiries] = enquiry_ratio(each_row.buyer_id)
      new_row[:type_of_match] = REVERSE_TYPE_OF_MATCH[each_row.type_of_match]
      qualifying_stage_detail_for_enquiry(each_row.buyer_id, new_row, each_row)
      new_row[:stage] = REVERSE_EVENTS[each_row.stage]
      new_row[:hotness] = REVERSE_EVENTS[enquiry.rating]
      new_row[:locked] = false

      ### If the property is closed won, include the details of the new buyer as well
      if each_row.stage == EVENTS[:closed_won_stage]
        sold_property = SoldProperty.where(udprn: each_row.udprn).last
        if sold_property
          new_row[:final_price] = sold_property.sale_price
          new_row[:final_price] ||= nil
          new_buyer = PropertyBuyer.where(id: sold_property.buyer_id)
                                   .select([:id, :email, :first_name, :last_name, :mobile, :status, :chain_free, :funding, 
                                            :biggest_problems, :buying_status, :budget_to, :budget_from,
                                            :first_name, :last_name, :image_url, :property_types])
                                   .last
          new_row[:actual_completion_date] = sold_property.completion_date
        end
        if new_buyer
          new_buyer.as_json.each do |key, value|
            new_key = 'new_vendor_' + key.to_s
            new_row[new_key.to_sym] = value
          end
        end

      end
      new_row[:actual_completion_date] ||= nil

    elsif @details[:verification_status].to_s == 'false'
      new_row[:locked] = true
      new_row[:reason] = 'The vendor not verified yet the property'
    elsif @details[:details_completed].to_s == 'false'
      new_row[:locked] = true
      new_row[:reason] = 'All the mandatory attrs are not yet completed'
    else 
      new_row[:locked] = true
      new_row[:reason] = 'All the mandatory attrs are not yet completed and the vendor has not verified the property'
    end
    new_row
  end

  def total_trackings
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
    if @is_premium && @old_stats_flag
      ### Last sold property date
      sp = SoldProperty.where(udprn: @udprn).select([:completion_date]).last
      if sp
        Events::Track.where('created_at > ?', sp.completion_date).where(type_of_tracking: event).where(udprn: @udprn).count
      else
        Events::Track.where(type_of_tracking: event).where(udprn: @udprn).count
      end
    else
      Events::Track.where(type_of_tracking: event).where(udprn: @udprn).count
    end
  end

  def property_being_tracked_by_buyer?(buyer_id)
    event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
    Events::Track.where(type_of_tracking: event).where(buyer_id: buyer_id).where(udprn: @udprn).count > 0
  end

  def enquiry_ratio(buyer_id)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    property_enquiries = buyer_enquiries = nil

    if @is_premium && @old_stats_flag
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

  def view_ratio(buyer_id)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    property_views = buyer_views = nil

    if @is_premium && @old_stats_flag
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

  def qualifying_stage_detail_for_enquiry(buyer_id, new_row, each_row)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    new_row[:scheduled_visit_time] = each_row.scheduled_visit_time
    new_row[:scheduled_visit_end_time] = each_row.scheduled_visit_end_time
    new_row[:offer_price] = each_row.offer_price
    new_row[:offer_date] = each_row.offer_date
    new_row[:expected_completion_date] = each_row.expected_completion_date
  end

  def add_buyer_details(details, buyer_hash)
    buyer_hash = buyer_hash.as_json.with_indifferent_access
    buyer = buyer_hash[details[:buyer_id].to_s]
    if buyer
      details[:buyer_status] = PropertyBuyer::REVERSE_STATUS_HASH[buyer[:status]] rescue nil
      details[:buyer_first_name] = buyer[:first_name]
      details[:buyer_last_name] = buyer[:last_name]
      details[:buyer_image] = buyer[:image_url]
      details[:buyer_email] = buyer[:email]
      details[:buyer_mobile] = buyer[:mobile]
      details[:chain_free] = buyer[:chain_free]
      details[:buyer_funding] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer[:funding]] rescue nil
      details[:buyer_biggest_problems] = buyer[:biggest_problems]
      details[:buyer_buying_status] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer[:buying_status]] rescue nil
      details[:buyer_budget_from] = buyer[:budget_from]
      details[:buyer_budget_to] = buyer[:budget_to]
      details[:buyer_budget_to] = buyer[:budget_to]
      details[:buyer_property_types] = buyer[:property_types]
    else
      keys = [:buyer_status, :buyer_first_name, :buyer_last_name, :buyer_image, :buyer_email, :buyer_mobile, :chain_free, :buyer_funding, :buyer_biggest_problems, :buyer_buying_status, :buyer_budget_from, :buyer_budget_to, :buyer_property_types]
      keys.each {|key| details[key] = nil }
    end
  end

  def agent_specific_enquiries(enquiry_type=nil, type_of_match=nil, qualifying_stage=nil, rating=nil, search_str=nil, last_time=nil, page=0, property_ids=[], service='Sale', buyer_ids=[])
    raise StandardError, 'Agent id is not present ' if @agent_id.nil?
    service = SERVICES[service]
    parsed_last_time = Time.parse(last_time) if last_time
    query = Event
    query = query.where("created_at > ?", parsed_last_time) if last_time
    query = query.where(buyer_id: filtered_buyer_ids) if buyer_filter_flag
    query = query.where(type_of_match:  TYPE_OF_MATCH[type_of_match.to_s.downcase.to_sym]) if type_of_match
    query = query.where(udprn: property_ids)
    query = query.where(buyer_id: buyer_ids) if !buyer_ids.empty?
  end

  def agent_specific_enquiry_details(page)
    property_ids = fetch_property_ids_for_agent
    buyer_filter_flag = buyer_buying_status || buyer_funding || buyer_biggest_problem || buyer_chain_free || budget_from || budget_to
    filtered_buyer_ids = fetch_filtered_buyer_ids(buyer_buying_status, buyer_funding, buyer_biggest_problem, buyer_chain_free, search_str, budget_from, budget_to) if buyer_filter_flag
    # filtered_buying_flag = (!buyer_buying_status.nil?) || (!buyer_funding.nil?) || (!buyer_biggest_problem.nil?) || (!buyer_chain_free.nil?)
  end

  def fetch_property_ids_for_agent
    raise StandardError, 'Agent id is not present ' if @agent_id.nil?
    api = PropertySearchApi.new(filtered_params: { agent_id: agent_id })
    api.apply_filters
    udprns, status = api.fetch_udprns
    udprns = [] if status.to_i != 200
    udprns.map { |e| e.to_i }
  end

  ##### Event.new.fetch_filtered_buyer_ids('First time buyer', 'Mortgage approved', 'Funding', true)
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

  def schedule_viewing(start_time, end_time, source)
    event = Event::EVENTS[:requested_viewing]
    agent_id = @agent_id
    property_id = @udprn
    message = nil
    buyer_id = @buyer_id
    type_of_match = 'perfect'
    property_status_type = nil

    ### Creates an enquiry only when the source is book viewing page
    insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event) if source == 'book_viewing'

    original_enquiries = Event.where(buyer_id: @buyer_id).where(udprn: @udprn).where(is_archived: false).order('created_at ASC')
    present_stage = original_enquiries.last.stage
    present_index = Event::QUALIFYING_STAGE_EVENTS.index(Trackers::Buyer::REVERSE_EVENTS[present_stage])
    event_index = Event::QUALIFYING_STAGE_EVENTS.index(:viewing_stage)
    enquiries = []
    if start_time.nil?
      return { message: 'Scheduled viewing time is null', details: nil }, 400
    elsif event_index < present_index
      return { message: 'Current stage of the property is ahead of viewing stage', details: nil }, 400
    else
      event = Event::EVENTS[:viewing_stage]
      original_enquiries.update_all(stage: event, scheduled_visit_time: start_time, scheduled_visit_end_time: end_time)
      agent_unavailability = AgentCalendarUnavailability.create!(
        buyer_id: @buyer_id,
        udprn: @udprn,
        start_time: Time.parse(start_time),
        end_time: Time.parse(end_time),
        agent_id: @agent_id,
        event_id: original_enquiries.last.id
      )
      enquiries = Enquiries::PropertyService.process_enquiries_result(original_enquiries)
      return { message: 'Created an invite in the calendar', details: agent_unavailability, enquiries: enquiries }, 200
    end

    ardb_client = Rails.configuration.ardb_client
    ardb_client.del("cache_#{@agent_id}_agent_new_enquiries") if @agent_id
    ardb_client.del("cache_#{@udprn}_enquiries")
    ardb_client.del("cache_#{@udprn}_interest_info")
    ardb_client.del("cache_#{@buyer_id}_history_enquiries")
    enquiries
  end

end

