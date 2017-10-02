class EventService
  include EventsHelper

  attr_accessor :udprn, :agent_id, :vendor_id, :service, :buyer_id, :details

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

  ENQUIRY_PAGE_SIZE = 20


  def initialize(udprn: udprn=nil, agent_id: agent_id=nil, vendor_id: vendor_id=nil, buyer_id: buyer_id=nil, last_time: time=nil)
    @udprn = udprn.to_i
    @agent_id = agent_id
    @vendor_id = vendor_id
    @buyer_id = buyer_id
    @last_time = last_time
    @details = PropertyDetails.details(@udprn.to_i)['_source'] if @udprn
  end

  def property_specific_enquiries(page)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    query = Event.where(udprn: @udprn)
    query = query.where("created_at > ?", @last_time) if @last_time
    query = query.where(buyer_id: @buyer_id) if @buyer_id
    query.order('created_at DESC').limit(ENQUIRY_PAGE_SIZE)
         .offset(ENQUIRY_PAGE_SIZE*page)
  end

  def property_specific_enquiry_details(page)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    enquiries = property_specific_enquiries(page)
    enquiry_details = enquiries.map { |enquiry| construct_enquiry_detail(enquiry) }
    buyer_ids = enquiry_details.map { |enquiry| enquiry[:buyer_id] }
    buyers = PropertyBuyer.where(id: buyer_ids.flatten).select([:id, :email, :full_name, :mobile, :status, :chain_free, :funding, :biggest_problem, :buying_status, :budget_to, :budget_from, :image_url]).order("position(id::text in '#{buyer_ids.join(',')}')")
    buyer_hash = {}
    buyers.each { |buyer| buyer_hash[buyer.id] = buyer }
    enquiry_details.each { |row| add_buyer_details(row, buyer_hash) }
    enquiry_details
  end

  def construct_enquiry_detail(enquiry)
    each_row = enquiry
    new_row = {}
    new_row[:id] = each_row.id
    new_row[:received] = each_row.created_at
    new_row[:type_of_enquiry] = REVERSE_EVENTS[each_row.event]
    new_row[:buyer_id] = each_row.buyer_id
    new_row[:property_tracking] = total_trackings
    new_row[:views] = view_ratio(each_row.buyer_id)
    new_row[:enquiries] = enquiry_ratio(each_row.buyer_id)
    new_row[:type_of_match] = REVERSE_TYPE_OF_MATCH[each_row.type_of_match]
    qualifying_stage_detail_for_enquiry(each_row.buyer_id, new_row, each_row)
    new_row[:stage] = REVERSE_EVENTS[each_row.stage]
    new_row[:hotness] = REVERSE_EVENTS[enquiry.rating]
    new_row
  end

  def total_trackings
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
    Events::Track.where(type_of_tracking: event).where(udprn: @udprn).count
  end

  def property_being_tracked_by_buyer?(buyer_id)
    event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
    Events::Track.where(type_of_tracking: event).where(buyer_id: buyer_id).where(udprn: @udprn).count > 0
  end

  def enquiry_ratio(buyer_id)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    buyer_enquiries = Events::EnquiryStatBuyer.new(buyer_id: buyer_id).enquiries
    total_enquiries = Events::EnquiryStatProperty.new(udprn: @udprn).enquiries
    buyer_enquiries.to_i.to_s + '/' + total_enquiries.to_i.to_s
  end

  def view_ratio(buyer_id)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    buyer_views = Events::EnquiryStatBuyer.new(buyer_id: buyer_id).views
    total_views = Events::EnquiryStatProperty.new(udprn: @udprn).views
    buyer_views.to_i.to_s + '/' + total_views.to_i.to_s
  end

  def qualifying_stage_detail_for_enquiry(buyer_id, new_row, each_row)
    raise StandardError, 'Udprn is not present ' if @udprn.nil?
    new_row[:scheduled_viewing_time] = each_row.scheduled_visit_time
    new_row[:offer_price] = each_row.offer_price
    new_row[:offer_date] = each_row.offer_date
    new_row[:expected_completion_date] = each_row.expected_completion_date
  end

  def add_buyer_details(details, buyer_hash)
    buyer_hash = buyer_hash.as_json.with_indifferent_access
    buyer = buyer_hash[details[:buyer_id].to_s]
    if buyer
      details[:buyer_status] = PropertyBuyer::REVERSE_STATUS_TYPES[buyer[:status]] rescue nil
      details[:buyer_full_name] = (buyer[:first_name] + buyer[:last_name]) rescue nil
      details[:buyer_image] = buyer[:image_url]
      details[:buyer_email] = buyer[:email]
      details[:buyer_mobile] = buyer[:mobile]
      details[:chain_free] = buyer[:chain_free]
      details[:buyer_funding] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer[:funding]] rescue nil
      details[:buyer_biggest_problem] = PropertyBuyer::REVERSE_BIGGEST_PROBLEM_HASH[buyer[:biggest_problem]] rescue nil
      details[:buyer_buying_status] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[buyer[:buying_status]] rescue nil
      details[:buyer_budget_from] = buyer[:budget_from]
      details[:buyer_budget_to] = buyer[:budget_to]
    else
      keys = [:buyer_status, :buyer_full_name, :buyer_image, :buyer_email, :buyer_mobile, :chain_free, :buyer_funding, :buyer_biggest_problem, :buyer_buying_status, :buyer_budget_from, :buyer_budget_to]
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

end
