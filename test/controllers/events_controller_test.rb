require 'minitest/autorun'
require 'test_helper'
require_relative '../helpers/es_helper'
require_relative '../helpers/events_helper'
require_relative '../helpers/quotes_helper'
require_relative '../helpers/udprn_helper'
# ruby -Itest path/to/tc_file.rb --name test_method_name
class EventsControllerTest < ActionController::TestCase
  include EsHelper
  include EventsHelper
  include QuotesHelper
  include UdprnHelper

  def setup
    @address_doc = SAMPLE_ADDRESS_DOC.deep_dup
    @address_doc_rent = SAMPLE_ADDRESS_DOC.deep_dup
    @address_doc_rent = @address_doc_rent.with_indifferent_acess
    @address_doc_rent['_source']['property_status_type'] = 'Rent'
    @address_doc_rent['_source']['udprn'] = '123456'
    index_es_address(SAMPLE_UDPRN, @address_doc['_source'])
    index_es_address('123456', @address_doc_rent['_source'])
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

    create_rent_enquiry_event
    attach_agent_to_property_and_update_details(agent_id, '123456', 'Rent', 
                                                verification_status, SAMPLE_BEDS, SAMPLE_BATHS, 
                                                SAMPLE_RECEPTIONS)


    property_status_type = 'Rent'

    get :agent_enquiries_by_property, { agent_id: agent_id, property_status_type: property_status_type }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1
    destroy_rent_enquiry_event
    ### TODO: Agent details have to be verified as well
  end

  ### Tests for agent_new_enquiries(Same as above action)
  def test_agent_new_enquiries
    agent_id = Agents::Branches::AssignedAgent.last.id
    verification_status = true
    get :agent_new_enquiries, { agent_id: agent_id }
    attach_agent_to_property_and_update_details(agent_id, SAMPLE_UDPRN, 'Green', 
                                                verification_status, SAMPLE_BEDS, SAMPLE_BATHS, 
                                                SAMPLE_RECEPTIONS)

    # assert_response 200
    # earlier_response = Oj.load(@response.body)
    # assert_equal earlier_response['enquiries'].length, 0
    len = 0
    buyer_id = PropertyBuyer.last.id

    property_details = get_es_address(SAMPLE_UDPRN)
    Trackers::Buyer::ENQUIRY_EVENTS.each do |event|
      process_event_helper(event, @address_doc['_source'], agent_id)
      get :agent_new_enquiries, { agent_id: agent_id }
      len += 1
      assert_response 200
      response = Oj.load(@response.body)
      assert_equal response['enquiries'].length, len

      ### Test property attributes
      attrs = ['price', 'street_view_image_url', 'udprn', 'offers_over', 
               'fixed_price', 'asking_price', 'dream_price', 'current_valuation', 'verification_status']
      attrs.each do |attr_val|
        assert_equal response['enquiries'].last[attr_val], property_details['_source'][attr_val]
      end

      assert_equal response['enquiries'].last['status'], property_details['_source']['property_status_type']

      ### Test buyer attributes
      buyer = PropertyBuyer.find(buyer_id).as_json
      buyer_attrs = ['id', 'status', 'full_name', 'email', 'image_url', 'mobile', 'budget_from', 'budget_to']
      buyer_attrs.each do |attr_val|
        assert_equal response['enquiries'].last["buyer_#{attr_val}"], buyer[attr_val]
      end

      assert_equal response['enquiries'].last['buyer_funding'], PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer['funding']]
      assert_equal response['enquiries'].last['buyer_biggest_problem'], PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer['biggest_problem']]
      assert_equal response['enquiries'].last['buyer_buying_status'], PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[buyer['buying_status']]
      
      ### Test enquiries, views, hotness and qualifying_stage 
      enquiries = response['enquiries'].last['enquiries']
      buyer_enquiries = enquiries.split('/')[0].to_i
      total_enquiries = enquiries.split('/')[1].to_i
      assert_equal buyer_enquiries, total_enquiries
    end

    ### Test viewed
    process_event_helper('viewed', @address_doc['_source'])
    get :agent_new_enquiries, { agent_id: agent_id }
    response = Oj.load(@response.body)
    views = response['enquiries'].last['views']
    buyer_views = views.split('/')[0].to_i
    total_views = views.split('/')[1].to_i
    assert_equal total_views, 1
    assert_equal buyer_views, 1


    ### Test hotness
    assert_equal response['enquiries'].last['hotness'], 'cold_property'
    process_event_helper('warm_property', @address_doc['_source'])
    get :agent_new_enquiries, { agent_id: agent_id }
    response = Oj.load(@response.body)
    hotness = response['enquiries'].last['hotness']
    assert_equal hotness, 'warm_property'

    process_event_helper('hot_property', @address_doc['_source'])
    get :agent_new_enquiries, { agent_id: agent_id }
    response = Oj.load(@response.body)
    hotness = response['enquiries'].last['hotness']
    assert_equal hotness, 'hot_property'

    #### Test qualifying stage filter
    (Trackers::Buyer::QUALIFYING_STAGE_EVENTS-[:qualifying_stage, :viewing_stage]).each do |event|
      process_event_helper(event, @address_doc['_source'])
      get :agent_new_enquiries, { agent_id: agent_id }
      response = Oj.load(@response.body)
      stage = response['enquiries'].last['qualifying']
      assert_equal stage, event.to_s

      get :agent_new_enquiries, { agent_id: agent_id, qualifying_stage: event }
      response = Oj.load(@response.body)
      response['enquiries'].each do |each_elem|
        assert_equal each_elem['qualifying'], event.to_s
      end

    end

    ### Test Filters
    ### i) enquiry_type
    (Trackers::Buyer::ENQUIRY_EVENTS-[:viewing_stage]).each do |event|
      get :agent_new_enquiries, { agent_id: agent_id, enquiry_type: event }
      response = Oj.load(@response.body)
      assert_equal response['enquiries'].length, 1
    end

    ### ii) type_of_match
    get :agent_new_enquiries, { agent_id: agent_id }
    response = Oj.load(@response.body)
    response_length = response['enquiries'].length

    get :agent_new_enquiries, { agent_id: agent_id, type_of_match: 'Potential' }
    response = Oj.load(@response.body)
    assert_equal response['enquiries'].length, 0

    get :agent_new_enquiries, { agent_id: agent_id, type_of_match: 'Perfect' }
    response = Oj.load(@response.body)
    # assert_equal response['enquiries'].length, response_length

    ### Test for rent properties
    create_rent_enquiry_event
    attach_agent_to_property_and_update_details(agent_id, '123456', 'Rent', 
                                                verification_status, SAMPLE_BEDS, SAMPLE_BATHS, 
                                                SAMPLE_RECEPTIONS)


    property_status_type = 'Rent'

    get :agent_new_enquiries, { agent_id: agent_id, property_for: 'Rent' }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1
    destroy_rent_enquiry_event
  end

  #### Tests for action recent_properties_for_quotes
  def test_recent_properties_for_quotes
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
    assert_equal response['quotes'].length, 0

    new_quote_for_property(SAMPLE_UDPRN)
    sleep(2)
    # update_es_address(SAMPLE_UDPRN, { verification_status: true } )
    
    get :recent_properties_for_quotes, { agent_id: agent_id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['quotes'].length, 1

    ### Test filters
    #### i) payment_terms
    get :recent_properties_for_quotes, { agent_id: agent_id, payment_terms: 'random val' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['quotes'].length, 0

    get :recent_properties_for_quotes, { agent_id: agent_id, payment_terms: SAMPLE_PAYMENT_TERMS }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['quotes'].length, 1

    ### ii) services_required
    get :recent_properties_for_quotes, { agent_id: agent_id, services_required: 'random val' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['quotes'].length, 0

    get :recent_properties_for_quotes, { agent_id: agent_id, services_required: SAMPLE_SERVICES_REQUIRED }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['quotes'].length, 1

    ### iii) quotes status
    get :recent_properties_for_quotes, { agent_id: agent_id, quote_status: 'Won' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['quotes'].length, 0

    get :recent_properties_for_quotes, { agent_id: agent_id, quote_status: 'New' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['quotes'].length, 1

    new_quote_by_agent(SAMPLE_UDPRN, agent_id)
    accept_quote_from_agent(SAMPLE_UDPRN, agent_id)
    get :recent_properties_for_quotes, { agent_id: agent_id, quote_status: 'Won' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['quotes'].length, 1

    ### Test for rent properties
    new_quote_for_property('123456')
    create_rent_enquiry_event
    new_quote_by_agent('123456', agent_id)
    accept_quote_from_agent('123456', agent_id)

    get :agent_new_enquiries, { agent_id: agent_id, property_for: 'Rent' }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1
    destroy_rent_enquiry_event
  end

  #### Tests for action recent_properties_for_claim
  def test_recent_properties_for_claim
    property_service = PropertyService.new(SAMPLE_UDPRN)
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!
    vendor_id = Vendor.last.id

    get :recent_properties_for_claim, { agent_id: agent.id }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['leads'].length, 0

    property_service.attach_vendor_to_property(vendor_id)
    get :recent_properties_for_claim, { agent_id: agent.id }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['leads'].length, 1
    assert_equal response['leads'].first['udprn'].to_i, SAMPLE_UDPRN.to_i


    #### Test filters
    get :recent_properties_for_claim, { agent_id: agent.id, status: 'Won' }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['leads'].length, 0

    get :recent_properties_for_claim, { agent_id: agent.id, status: 'New' }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['leads'].length, 1


    ### For rent properties
    property_service = PropertyService.new('123456')
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!
    property_service.attach_vendor_to_property(vendor_id)
    get :recent_properties_for_claim, { agent_id: agent.id, property_for: 'Rent' }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['leads'].length, 1
  end


  ### property_enquiries test is similar to agents_new_enquiries
  def test_detailed_properties_for_leads_properties
    property_service = PropertyService.new(SAMPLE_UDPRN)
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!
    vendor_id = Vendor.last.id

    get :detailed_properties, { agent_id: agent.id }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['properties'].length, 0

    ### Create a new lead
    property_service.attach_vendor_to_property(vendor_id)

    ### Claim that lead for the agent
    post :claim_property, { udprn: SAMPLE_UDPRN.to_i, agent_id: agent.id }

    get :detailed_properties, { agent_id: agent.id }

    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['properties'].length, 1
  end

  ### property_enquiries test is similar to agents_new_enquiries
  def test_detailed_properties_for_leads_properties_for_rent
    property_service = PropertyService.new('123456')
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!
    vendor_id = Vendor.last.id

    get :detailed_properties, { agent_id: agent.id, property_for: 'Rent' }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['properties'].length, 0

    ### Create a new lead
    property_service.attach_vendor_to_property(vendor_id)

    ### Claim that lead for the agent
    post :claim_property, { udprn: '123456'.to_i, agent_id: agent.id }
    sleep(3)
    get :detailed_properties, { agent_id: agent.id, property_for: 'Rent' }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response['properties'].length, 1
  end

  def test_detailed_properties_for_quotes_properties
    new_quote_for_property(SAMPLE_UDPRN)
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!

    get :detailed_properties, { agent_id: agent.id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 0

    new_quote_by_agent(SAMPLE_UDPRN, agent.id)
    get :detailed_properties, { agent_id: agent.id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1

    accept_quote_from_agent(SAMPLE_UDPRN, agent.id)
    get :detailed_properties, { agent_id: agent.id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1
  end

  def test_detailed_properties_for_quotes_properties_for_rent
    rent_udprn = '123456'
    new_quote_for_property(rent_udprn)
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!

    get :detailed_properties, { agent_id: agent.id, property_for: 'Rent' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 0

    new_quote_by_agent(rent_udprn, agent.id)
    get :detailed_properties, { agent_id: agent.id, property_for: 'Rent' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1

    accept_quote_from_agent(rent_udprn, agent.id)
    get :detailed_properties, { agent_id: agent.id, property_for: 'Rent' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1
  end

  def test_detailed_properties_for_agents_properties
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!
    verification_status = true

    attach_agent_to_property_and_update_details(agent.id, SAMPLE_UDPRN, 'Green', 
                                                verification_status, SAMPLE_BEDS, SAMPLE_BATHS, 
                                                SAMPLE_RECEPTIONS)
    get :detailed_properties, { agent_id: agent.id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1
  end

  def test_detailed_properties_for_agents_properties_for_rent
    agent = Agents::Branches::AssignedAgent.last
    new_agent = Agents::Branches::AssignedAgent.new(Agents::Branches::AssignedAgent.last.as_json)
    new_agent.id = nil
    new_agent.email = "ghhh@j.com"
    branch = Agents::Branch.last
    new_agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert new_agent.save!(validate: false)
    assert branch.save!
    verification_status = true

    attach_agent_to_property_and_update_details(new_agent.id, '123456', 'Rent', 
                                                verification_status, SAMPLE_BEDS, SAMPLE_BATHS, 
                                                SAMPLE_RECEPTIONS)
    get :detailed_properties, { agent_id: new_agent.id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 0

    get :detailed_properties, { agent_id: new_agent.id, property_for: 'Rent' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1
  end


  def test_detailed_properties_filters
    other_test_udprns = (1..2).map { |e| SAMPLE_UDPRN.to_i + e }
    other_test_udprns.each do |other_udprn|
      address_doc = SAMPLE_ADDRESS_DOC.deep_dup
      address_doc['_source']['udprn'] = other_udprn
      index_es_address(other_udprn, address_doc['_source'])
    end
    sleep(2)

    #### agent data fixing part
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!
    verification_status = true
    vendor_id = Vendor.last.id

    #### Attach agent to sample udprn
    attach_agent_to_property_and_update_details(agent.id, SAMPLE_UDPRN, 'Green', 
                                                verification_status, SAMPLE_BEDS, SAMPLE_BATHS, 
                                                SAMPLE_RECEPTIONS)


    #### Submit quote for second property
    new_quote_for_property(other_test_udprns.first)
    new_quote_by_agent(other_test_udprns.first, agent.id)

    #### Claim third property
    property_service = PropertyService.new(other_test_udprns.second)
    property_service.attach_vendor_to_property(vendor_id)
    post :claim_property, { udprn: other_test_udprns.second.to_i, agent_id: agent.id }

    get :detailed_properties, { agent_id: agent.id }
    response = Oj.load(@response.body)
    assert_response 200
    assert response.has_key?('properties')
    assert_equal response['properties'].length, 3


    ### Test ads false filter
    update_es_address(SAMPLE_UDPRN, { ads: false })
    
    get :detailed_properties, { agent_id: agent.id, ads: false }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1

    get :detailed_properties, { agent_id: agent.id, ads: true }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 0


    ### Test property status type filter
    update_es_address(other_test_udprns.first, { property_status_type: 'Red' })
    update_es_address(other_test_udprns.second, { property_status_type: 'Amber' })
    sleep(2)
    get :detailed_properties, { agent_id: agent.id, property_status_type: 'Amber' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1

    get :detailed_properties, { agent_id: agent.id, property_status_type: 'Amber' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1

    get :detailed_properties, { agent_id: agent.id, property_status_type: 'Green' }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['properties'].length, 1

    other_test_udprns.each do |other_udprn|
      delete_es_address(other_udprn.to_s)
    end
  end

  ### Test 
  def teardown
    delete_es_address(SAMPLE_UDPRN)
    Event.destroy_all
    Agents::Branches::AssignedAgents::Quote.destroy_all
  end

end
