require 'minitest/autorun'
require 'test_helper'
require_relative '../helpers/es_helper'
require_relative '../helpers/events_helper'
require_relative '../helpers/quotes_helper'
# ruby -Itest path/to/tc_file.rb --name test_method_name
class EventsControllerTest < ActionController::TestCase
  include EsHelper
  include EventsHelper
  include QuotesHelper
  SAMPLE_TEXT_STR = 'douglas road liverpool'
  SAMPLE_HASH = 'LIVERPOOL_Douglas Road'
  SAMPLE_OUTPUT = "Douglas Road, LIVERPOOL, Merseyside"
  SAMPLE_THOROUGHFARE_DESCRIPTOR = 'Douglas Road'
  SAMPLE_BUILDING_NUMBER = '6'
  SAMPLE_BUILDING_NAME = SAMPLE_BUILDING_NUMBER + ' Ember Society'
  SAMPLE_COUNTY = 'Merseyside'
  SAMPLE_POST_TOWN = 'LIVERPOOL'
  SAMPLE_AREA = 'L'
  SAMPLE_DISTRICT = 'L4'
  SAMPLE_POSTCODE = 'L4 2RQ'
  SAMPLE_SECTOR = 'L4 2'
  SAMPLE_DEPENDENT_LOCALITY = "Birkenhead"
  SAMPLE_HIERARCHY = "#{SAMPLE_THOROUGHFARE_DESCRIPTOR}|#{SAMPLE_DEPENDENT_LOCALITY}|#{SAMPLE_POST_TOWN}|#{SAMPLE_COUNTY}"
  SAMPLE_ROAD = 'Mount Road'
  SAMPLE_UDPRN = "12345"
  SAMPLE_ADDRESS_DOC = {"_index"=>"test_addresses", "_type"=>"test_address", "_id"=>SAMPLE_UDPRN, "_score"=>1.0, "_source"=>{"area"=> SAMPLE_AREA, "building_number"=> SAMPLE_BUILDING_NUMBER, "county"=> SAMPLE_COUNTY, "dependent_locality"=> SAMPLE_DEPENDENT_LOCALITY, "dependent_thoroughfare_description"=>SAMPLE_ROAD, "district"=> SAMPLE_DISTRICT, "hashes"=>["BIRKENHEAD", "Merseyside", "BIRKENHEAD_Birkenhead", "BIRKENHEAD_Birkenhead_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Oxton", "BIRKENHEAD_Oxton_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Prenton", "BIRKENHEAD_Prenton_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Rock Ferry", "BIRKENHEAD_Rock Ferry_Mount Road", "BIRKENHEAD_Rock Ferry_Mount Road_142"], "match_type_str"=>["BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Birkenhead|Normal", "BIRKENHEAD_Birkenhead_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Oxton|Normal", "BIRKENHEAD_Oxton_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Prenton|Normal", "BIRKENHEAD_Prenton_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Rock Ferry|Normal", "BIRKENHEAD_Rock Ferry_Mount Road|Normal", "BIRKENHEAD_Rock Ferry_Mount Road_142|Normal"], "post_code"=>SAMPLE_POSTCODE, "post_town"=>"BIRKENHEAD", "postcode"=>SAMPLE_POSTCODE.split(' ').join(''), "postcode_type"=>"S", "sector"=>SAMPLE_SECTOR, "unit"=>SAMPLE_POSTCODE.split(' ').join(''), "udprn"=>SAMPLE_UDPRN, "vanity_url"=>"6-embers-society-mount-road-birkenhead-merseyside-CH428NN", "photo_urls"=>[], "agent_employee_email_address"=>"b@c.com", "property_style"=>"Don’t know", "epc"=>"No", "receptions"=>nil, "decorative_condition"=>"Needs modernisation", "price_last_updated"=>nil, "total_property_size"=>nil, "agent_employee_mobile_number"=>"9876543210", "assigned_agent_employee_address"=>"5 Bina Gardens", "last_sale_date"=>"2016-06-27", "valuation"=>128000, "floors"=>6, "assigned_agent_employee_name"=>"John Smith", "description"=>nil, "cost_per_month"=>4900, "property_status_type"=>"Green", "year_built"=>"1961-01-01", "listing_type"=>"Basic", "chain_free"=>"Yes", "improvement_spend"=>5557, "price"=>720000, "beds"=>nil, "internal_property_size"=>nil, "street_view_image_url"=>"https://s3-us-west-2.amazonaws.com/propertyuk/11292578_street_view.jpg", "verification_status"=>false, "last_sale_price"=>503999, "last_listing_updated"=>"2 minutes ago", "agent_employee_name"=>"John Clarke", "budget"=>280000, "agent_employee_profile_image"=>"https://st.zoocdn.com/zoopla_static_agent_logo_(44631).data", "outside_space_type"=>"Terrace", "parking_type"=>"Single garage", "central_heating"=>"None", "valuation_date"=>"2016-01-15", "added_by"=>"Us", "date_added"=>"2016-07-31", "broker_branch_contact"=>"020 3641 4259", "additional_features_type"=>["Swimming pool"], "last_sale_price_date"=>"2012-01-14", "floorplan"=>"No", "monitoring_type"=>"No", "time_frame"=>"2012-01-01", "baths"=>nil, "agent_logo"=>nil, "assigned_agent_employee_image"=>nil, "broker_logo"=>nil, "last_updated_date"=>"2015-09-21", "listed_status"=>"Locally listed", "verification_time"=>"2016-06-18 21:32:44", "photos"=>["https://s3-us-west-2.amazonaws.com/propertyuk/11292578_street_view.jpg"], "current_valuation"=>553846, "property_type"=>nil, "agent_branch_name"=>"Dwellings", "address"=>"142, Mount Road, Birkenhead", "date_updated"=>"2017-01-11", "agent_contact"=>"020 3641 4259", "tenure"=>nil, "dream_price"=>720000, "status_last_updated"=>"2016-07-30 21:32:44", "external_property_size"=>nil, "asking_price" => 65000, "pictures" => [] }}
  SAMPLE_LOCATION_DOC = { "_index"=> "test_locations", "_type"=> "test_location", "_id"=> SAMPLE_HASH, "_score"=> 1, "_source"=> { "hashes"=> SAMPLE_HASH, "suggest"=> { "input"=> [ SAMPLE_TEXT_STR ], "output"=> SAMPLE_TEXT_STR, "weight"=> 10, "payload"=> { "hash"=> SAMPLE_HASH, "hierarchy_str"=> SAMPLE_HIERARCHY, "postcode"=> SAMPLE_POSTCODE, "type"=> "thoroughfare_description" } } } }
  SAMPLE_BEDS = 3
  SAMPLE_BATHS = 3
  SAMPLE_RECEPTIONS = 2

  def setup
    @address_doc = SAMPLE_ADDRESS_DOC.deep_dup
    index_es_address(SAMPLE_UDPRN, @address_doc['_source'])
    sleep(1)
  end

  #### Tests for process_event method tests
  def test_process_event_tracking_events
    Trackers::Buyer::TRACKING_EVENTS.each do |event|
      process_event_helper(event, @address_doc['_source'])
    end
  end

  def test_process_event_enquiry_events
    Trackers::Buyer::ENQUIRY_EVENTS.each do |event|
      process_event_helper(event, @address_doc['_source'])
    end
  end

  def test_process_event_qualifying_stage_events
    Trackers::Buyer::QUALIFYING_STAGE_EVENTS.each do |event|
      process_event_helper(event, @address_doc['_source'])
    end
  end

  def test_process_event_all_events
    Trackers::Buyer::EVENTS.each do |event|
      process_event_helper(event, @address_doc['_source'])
    end
  end

  #### Tests for agent_enquiries_by_property action
  def test_agent_enquiries_by_property
    agent_id = Agents::Branches::AssignedAgent.last.id
    get :agent_enquiries_by_property, { agent_id: agent_id }
    earlier_response = Oj.load(@response.body)
    verification_status = true
    attach_agent_to_property_and_update_details(agent_id, SAMPLE_UDPRN, 'Green', 
                                                verification_status, SAMPLE_BEDS, SAMPLE_BATHS, 
                                                SAMPLE_RECEPTIONS)
    enquiry_count = 0

    Trackers::Buyer::ENQUIRY_EVENTS.each do |event|
      process_event_helper(event, @address_doc['_source'])
      @address_doc['_source'].delete('agent_id')
      get :agent_enquiries_by_property, { agent_id: agent_id }
      assert_response 200

      ### Check for the event
      response = Oj.load(@response.body)
      event_value = response.first[event.to_s]
      if event.to_s != 'viewing_stage'
        assert_equal event_value, 1
      end

      assert_equal response.length, (earlier_response.length + 1)

      ### Check for the property attrs of the body
      attrs = ['udprn', 'beds', 'baths', 'receptions']
      attrs.each do |attr_val|
        assert_equal response.first[attr_val], eval("SAMPLE_#{attr_val.upcase}")
      end

      enquiry_count = enquiry_count + 1
      #### Check if the total number of enquiries are increasing
      assert_equal response.first['total_enquiries'], enquiry_count
    end

    other_events = ['offer_made_stage', 'deleted']
    other_events.each do |event|
      process_event_helper(event, @address_doc['_source'])
      get :agent_enquiries_by_property, { agent_id: agent_id }
      response = Oj.load(@response.body)
      event_value = response.first[event.to_s]
      assert_equal event_value, 1
    end

    total_trackings = 0
    Trackers::Buyer::TRACKING_EVENTS.each do |event|
      process_event_helper(event, @address_doc['_source'])
      get :agent_enquiries_by_property, { agent_id: agent_id }
      response = Oj.load(@response.body)
      count = response.first['trackings']
      total_trackings += 1
      assert_equal count, total_trackings
    end

    ### Test for verification status filter
    new_verification_status = !verification_status
    get :agent_enquiries_by_property, { agent_id: agent_id, verification_status: new_verification_status }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 0

    new_verification_status = !new_verification_status
    get :agent_enquiries_by_property, { agent_id: agent_id, verification_status: new_verification_status }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1


    ### Test for property_status_type_filter
    property_status_type = 'Red'
    get :agent_enquiries_by_property, { agent_id: agent_id, property_status_type: property_status_type }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 0

    property_status_type = 'Green'
    get :agent_enquiries_by_property, { agent_id: agent_id, property_status_type: property_status_type }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1

    ### TODO: Agent details have to be verified as well
  end

  ### Tests for agent_new_enquiries(Same as above action)
  def test_agent_new_enquiries
    agent_id = Agents::Branches::AssignedAgent.last.id
    get :agent_new_enquiries, { agent_id: agent_id }
    verification_status = true
    attach_agent_to_property_and_update_details(agent_id, SAMPLE_UDPRN, 'Green', 
                                                verification_status, SAMPLE_BEDS, SAMPLE_BATHS, 
                                                SAMPLE_RECEPTIONS)
    # p @response.body
    assert_response 200
    earlier_response = Oj.load(@response.body)
    assert_equal earlier_response.length, 0
    len = 0
    buyer_id = PropertyBuyer.last.id

    property_details = get_es_address(SAMPLE_UDPRN)
    Trackers::Buyer::ENQUIRY_EVENTS.each do |event|
      process_event_helper(event, @address_doc['_source'])
      get :agent_new_enquiries, { agent_id: agent_id }
      len += 1
      assert_response 200
      response = Oj.load(@response.body)
      assert_equal response.length, len

      ### Test property attributes
      attrs = ['price', 'street_view_image_url', 'udprn', 'offers_over', 
               'fixed_price', 'asking_price', 'dream_price', 'current_valuation', 'verification_status']
      attrs.each do |attr_val|
        assert_equal response.last[attr_val], property_details['_source'][attr_val]
      end

      assert_equal response.last['status'], property_details['_source']['property_status_type']

      ### Test buyer attributes
      buyer = PropertyBuyer.find(buyer_id).as_json
      buyer_attrs = ['id', 'status', 'full_name', 'email', 'image_url', 'mobile', 'budget_from', 'budget_to']
      buyer_attrs.each do |attr_val|
        assert_equal response.last["buyer_#{attr_val}"], buyer[attr_val]
      end

      assert_equal response.last['buyer_funding'], PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer['funding']]
      assert_equal response.last['buyer_biggest_problem'], PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer['biggest_problem']]
      assert_equal response.last['buyer_buying_status'], PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer['buying_status']]
      
      ### Test enquiries, views, hotness and qualifying_stage 
      enquiries = response.last['enquiries']
      buyer_enquiries = enquiries.split('/')[0].to_i
      total_enquiries = enquiries.split('/')[1].to_i
      assert_equal buyer_enquiries, total_enquiries


    end

    ### Test viewed
    process_event_helper('viewed', @address_doc['_source'])
    get :agent_new_enquiries, { agent_id: agent_id }
    response = Oj.load(@response.body)
    views = response.last['views']
    buyer_views = views.split('/')[0].to_i
    total_views = views.split('/')[1].to_i
    assert_equal total_views, 1
    assert_equal buyer_views, 1


    ### Test hotness
    assert_equal response.last['hotness'], 'cold_property'
    process_event_helper('warm_property', @address_doc['_source'])
    get :agent_new_enquiries, { agent_id: agent_id }
    response = Oj.load(@response.body)
    hotness = response.last['hotness']
    assert_equal hotness, 'warm_property'

    process_event_helper('hot_property', @address_doc['_source'])
    get :agent_new_enquiries, { agent_id: agent_id }
    response = Oj.load(@response.body)
    hotness = response.last['hotness']
    assert_equal hotness, 'hot_property'

    #### Test qualifying stage filter
    (Trackers::Buyer::QUALIFYING_STAGE_EVENTS-[:qualifying_stage, :viewing_stage]).each do |event|
      process_event_helper(event, @address_doc['_source'])
      get :agent_new_enquiries, { agent_id: agent_id }
      response = Oj.load(@response.body)
      stage = response.last['qualifying']
      assert_equal stage, event.to_s

      get :agent_new_enquiries, { agent_id: agent_id, qualifying_stage: event }
      response = Oj.load(@response.body)
      response.each do |each_elem|
        assert_equal each_elem['qualifying'], event.to_s
      end

    end

    ### Test Filters
    ### i) enquiry_type
    (Trackers::Buyer::ENQUIRY_EVENTS-[:viewing_stage]).each do |event|
      get :agent_new_enquiries, { agent_id: agent_id, enquiry_type: event }
      response = Oj.load(@response.body)
      assert_equal response.length, 1
    end

    ### ii) type_of_match
    get :agent_new_enquiries, { agent_id: agent_id }
    response = Oj.load(@response.body)
    response_length = response.length

    get :agent_new_enquiries, { agent_id: agent_id, type_of_match: 'Potential' }
    response = Oj.load(@response.body)
    assert_equal response.length, 0

    get :agent_new_enquiries, { agent_id: agent_id, type_of_match: 'Perfect' }
    response = Oj.load(@response.body)
    assert_equal response.length, response_length
  end

  #### Tests for action recent_properties_for_quotes
  def test_recent_properties_for_quotes
    new_quote_for_property(SAMPLE_UDPRN)
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!
    agent_id = Agents::Branches::AssignedAgent.last.id
    get :recent_properties_for_quotes, { agent_id: agent_id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 0

    update_es_address(SAMPLE_UDPRN, { verification_status: true } )
    
    get :recent_properties_for_quotes, { agent_id: agent_id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 1

    ### Test filters
    #### i) payment_terms
    get :recent_properties_for_quotes, { agent_id: agent_id, payment_terms: 'random val' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 0

    get :recent_properties_for_quotes, { agent_id: agent_id, payment_terms: SAMPLE_PAYMENT_TERMS }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 1

    #### ii) services_required
    get :recent_properties_for_quotes, { agent_id: agent_id, services_required: 'random val' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 0

    get :recent_properties_for_quotes, { agent_id: agent_id, services_required: SAMPLE_SERVICES_REQUIRED }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 1

    ### iii) quotes status
    get :recent_properties_for_quotes, { agent_id: agent_id, quote_status: 'Won' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 0

    get :recent_properties_for_quotes, { agent_id: agent_id, quote_status: 'New' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 1

    new_quote_by_agent(SAMPLE_UDPRN, agent_id)
    accept_quote_from_agent(SAMPLE_UDPRN, agent_id)
    get :recent_properties_for_quotes, { agent_id: agent_id, quote_status: 'Won' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response.length, 1
  end

  #### Tests for action recent_properties_for_claim
  def test_recent_properties_for_claim
    
  end

  ### Test 
  def teardown
    delete_es_address(SAMPLE_UDPRN)
    Event.destroy_all
    Agents::Branches::AssignedAgents::Quote.destroy_all
  end

end