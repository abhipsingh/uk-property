require 'minitest/autorun'
require 'test_helper'
require_relative '../helpers/es_helper'
require_relative '../helpers/events_helper'
require_relative '../helpers/quotes_helper'
require_relative '../helpers/udprn_helper'
require_relative '../helpers/agents_helper'
# ruby -Itest path/to/tc_file.rb --name test_method_name
class PropertiesControllerTest < ActionController::TestCase
  include EsHelper
  include EventsHelper
  include QuotesHelper
  include UdprnHelper
  include AgentsHelper

  def setup
    @address_doc = SAMPLE_ADDRESS_DOC.deep_dup
    index_es_address(SAMPLE_UDPRN, @address_doc['_source'])
    sleep(1)
    password = "123456789"
    @vendor_authorization_token = AuthenticateUser.call(Vendor.last.email,"123456789",Vendor).result
    @agent_authorization_token  = AuthenticateUser.call(Agents::Branches::AssignedAgent.last.email,"123456789",Agents::Branches::AssignedAgent).result
  end

  def test_edit_property_details
    # AuthenticateUser.call(vendor_params['email'], vendor_params['password'], Vendor)
    @request.env['Authorization'] = @agent_authorization_token
    sample_number = (1..100).to_a.sample
    random_str = 'random'
    request_hash = {
      udprn: SAMPLE_UDPRN,
      details: {
        beds: sample_number,
        baths: sample_number,
        receptions: sample_number,
        property_type: random_str,
        current_valuation: sample_number,
        tenure: sample_number,
        floors: sample_number
      }
    }
    @request.headers['Authorization'] = @agent_authorization_token
    post :edit_property_details, request_hash
    details = Oj.load(@response.body)['response']
    doc = get_es_address(SAMPLE_UDPRN)['_source']
    assert_response 200
    assert_equal doc['beds'], sample_number
    assert_equal doc['baths'], sample_number
    assert_equal doc['receptions'], sample_number
    assert_equal doc['property_type'], random_str
    assert_equal doc['current_valuation'], sample_number
    assert_equal doc['tenure'], sample_number
    assert_equal doc['current_valuation'], sample_number
  end

  def test_historic_pricing
    historic_details = PropertyHistoricalDetail.last
    historic_details.udprn = SAMPLE_UDPRN
    historic_details.save
    get :historic_pricing, { udprn: SAMPLE_UDPRN }
    assert_response 200
    # p response.body
  end

  def test_enquiries
    event = Trackers::Buyer::ENQUIRY_EVENTS.sample
    process_event_helper(event, @address_doc['_source'])
    @request.headers['Authorization'] = @agent_authorization_token
    get :enquiries, { udprn: SAMPLE_UDPRN }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1
    assert_equal response[0]['type_of_enquiry'], event.to_s
  end

  def test_interest_info
    ### An enquiry
    event = Trackers::Buyer::ENQUIRY_EVENTS.sample
    process_event_helper(event, @address_doc['_source'])

    interest_events = [ :interested_in_viewing, :interested_in_making_an_offer, :requested_message, :requested_callback, :requested_viewing, :deleted, :property_tracking ]
    interest_events.map { |e| process_event_helper(e, @address_doc['_source']) }
    @request.headers['Authorization'] = @agent_authorization_token
    get :interest_info, { udprn: SAMPLE_UDPRN }
    assert_response 200
    response = Oj.load(@response.body)
    interest_events.each do |interest_event|
      cond = ( response[interest_event.to_s][0]['count'].to_i > 0 )
      assert cond
    end
  end

  def test_supply_info
    get :supply_info, { udprn: SAMPLE_UDPRN }
    # p @response.body
    assert_response 200
  end

  def test_demand_info
    get :demand_info, { udprn: SAMPLE_UDPRN }
    # p @response.body
    assert_response 200
  end

  def test_buyer_profile_stats
    get :demand_info, { udprn: SAMPLE_UDPRN }
    assert_response 200
  end

  def test_agent_stage_and_rating_stats
    # get :agent_stage_and_rating_stats, { udprn: SAMPLE_UDPRN }
    # assert_response 200
  end

  def test_ranking_stats
    get :ranking_stats, { udprn: SAMPLE_UDPRN }
    assert_response 200
  end

  def test_history_enquiries
    ### An enquiry
    event = Trackers::Buyer::ENQUIRY_EVENTS.sample
    process_event_helper(event, @address_doc['_source'])
    get :history_enquiries, { buyer_id: PropertyBuyer.first.id }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1
    assert_equal response[0]['type_of_enquiry'], event.to_s
  end

  def test_edit_basic_details
    sample_number = (1..10).to_a.sample

    request_hash = {
      udprn: SAMPLE_UDPRN,
      dream_price: sample_number,
      beds: sample_number,
      baths: sample_number,
      receptions: sample_number
    }

    post :edit_basic_details, request_hash
    assert_response 200
    details = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal details['beds'], sample_number
    assert_equal details['baths'], sample_number
    assert_equal details['receptions'], sample_number
    assert_equal details['dream_price'], sample_number
    assert_equal details['verification_status'], false
  end

  def test_claim_udprn
    vendor_id = Vendor.last.id
    request_hash = {
      vendor_id: vendor_id,
      udprn: SAMPLE_UDPRN
    }
    post :claim_udprn, request_hash
    assert_response 200
    details = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal details['vendor_id'], vendor_id
    assert_equal details['verification_status'], false
  end

  def test_update_basic_details_by_vendor
    sample_number = (1..10).to_a.sample
    random_str = 'random'
    vendor_id = Vendor.last.id
    request_hash = {
      udprn: SAMPLE_UDPRN,
      beds: sample_number,
      baths: sample_number,
      vendor_id: vendor_id,
      receptions: sample_number,
      property_type: random_str,
      property_status_type: 'Green'
    }
    post :update_basic_details_by_vendor, request_hash
    assert_response 200
    details = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal details['vendor_id'], vendor_id
    assert_equal details['verification_status'], false
    assert_equal details['beds'], sample_number
    assert_equal details['baths'], sample_number
    assert_equal details['receptions'], sample_number
    assert_equal details['property_type'], random_str
  end

  def teardown
    delete_all_docs
  end
end