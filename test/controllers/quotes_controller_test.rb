require 'minitest/autorun'
require 'test_helper'
require_relative '../helpers/es_helper'
require_relative '../helpers/events_helper'
require_relative '../helpers/quotes_helper'
require_relative '../helpers/udprn_helper'
# ruby -Itest path/to/tc_file.rb --name test_method_name
class QuotesControllerTest < ActionController::TestCase
  include EsHelper
  include EventsHelper
  include QuotesHelper
  include UdprnHelper

  def setup
    @address_doc = SAMPLE_ADDRESS_DOC.deep_dup
    @address_doc_rent = SAMPLE_ADDRESS_DOC.deep_dup
    @address_doc_rent['_source']['property_status_type'] = 'Rent'
    @address_doc_rent['_source']['udprn'] = '123456'
    @address_doc_rent['_id'] = '123456'
    index_es_address(SAMPLE_UDPRN, @address_doc['_source'])
    index_es_address('123456', @address_doc_rent['_source'])
    sleep(1)
  end

  def test_new_quote_for_property
    params_hash = {
      udprn: SAMPLE_UDPRN,
      services_required: SAMPLE_SERVICES_REQUIRED,
      payment_terms: SAMPLE_PAYMENT_TERMS,
      quote_details: SAMPLE_QUOTE_DETAILS.to_json,
      assigned_agent: false
    }
    prev_quote_count = Agents::Branches::AssignedAgents::Quote.count
    post :new_quote_for_property, params_hash

    assert_response 200
    response = get_es_address(SAMPLE_UDPRN)
    quote = Agents::Branches::AssignedAgents::Quote.last
    assert_equal quote.quote_details.to_json, SAMPLE_QUOTE_DETAILS.to_json
    assert_equal Agents::Branches::AssignedAgents::Quote.count, (prev_quote_count + 1)
  end

  def test_new_quote_for_property_rent
    params_hash = {
      udprn: '123456',
      services_required: SAMPLE_SERVICES_REQUIRED,
      payment_terms: SAMPLE_PAYMENT_TERMS,
      quote_details: SAMPLE_QUOTE_DETAILS.to_json,
      assigned_agent: false
    }
    prev_quote_count = Agents::Branches::AssignedAgents::Quote.count
    post :new_quote_for_property, params_hash

    assert_response 200
    response = get_es_address('123456')
    quote = Agents::Branches::AssignedAgents::Quote.last
    assert_equal quote.quote_details.to_json, SAMPLE_QUOTE_DETAILS.to_json
    assert_equal Agents::Branches::AssignedAgents::Quote.count, (prev_quote_count + 1)
  end

  ### When a new quote is entered by an agent, test if the price is set
  def test_new
    quote_details = SAMPLE_QUOTE_DETAILS.deep_dup
    quote_details['fixed_price_services_requested']['price'] = 1200
    params_hash = {
      udprn: SAMPLE_UDPRN,
      services_required: SAMPLE_SERVICES_REQUIRED,
      payment_terms: SAMPLE_PAYMENT_TERMS,
      quote_details: quote_details.to_json
    }
    first_params_hash = params_hash.deep_dup
    first_params_hash[:quote_details] = SAMPLE_QUOTE_DETAILS.to_json
    post :new_quote_for_property, first_params_hash
    prev_quote_count = Agents::Branches::AssignedAgents::Quote.count
    post :new, params_hash
    assert_response 200
    assert_equal Agents::Branches::AssignedAgents::Quote.count, (prev_quote_count + 1)
  end

  ### When a new quote is entered by an agent for rent, test if the price is set
  def test_new_rent
    quote_details = SAMPLE_QUOTE_DETAILS.deep_dup
    quote_details['fixed_price_services_requested']['price'] = 1200
    params_hash = {
      udprn: '123456',
      services_required: SAMPLE_SERVICES_REQUIRED,
      payment_terms: SAMPLE_PAYMENT_TERMS,
      quote_details: quote_details.to_json
    }
    first_params_hash = params_hash.deep_dup
    first_params_hash[:quote_details] = SAMPLE_QUOTE_DETAILS.to_json
    post :new_quote_for_property, first_params_hash
    prev_quote_count = Agents::Branches::AssignedAgents::Quote.count
    post :new, params_hash
    assert_response 200
    assert_equal Agents::Branches::AssignedAgents::Quote.count, (prev_quote_count + 1)
  end

  ### When a quote of an agent is accepted by the vendor
  def test_submit
    quote_details = SAMPLE_QUOTE_DETAILS.deep_dup
    quote_details['fixed_price_services_requested']['price'] = 1200
    params_hash = {
      udprn: SAMPLE_UDPRN,
      services_required: SAMPLE_SERVICES_REQUIRED,
      payment_terms: SAMPLE_PAYMENT_TERMS,
      quote_details: quote_details.to_json
    }
    first_params_hash = params_hash.deep_dup
    first_params_hash[:quote_details] = SAMPLE_QUOTE_DETAILS.to_json
    post :new_quote_for_property, first_params_hash
    post :new, params_hash
    assert_response 200

    quote = Agents::Branches::AssignedAgents::Quote.last
    ### Now lets submit the quote
    post :submit, { udprn: SAMPLE_UDPRN, quote_id: quote.id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['message'], 'The quote is accepted'
  end

  ### When a quote of an agent is accepted by the vendor
  def test_submit_rent
    quote_details = SAMPLE_QUOTE_DETAILS.deep_dup
    quote_details['fixed_price_services_requested']['price'] = 1200
    params_hash = {
      udprn: '123456',
      services_required: SAMPLE_SERVICES_REQUIRED,
      payment_terms: SAMPLE_PAYMENT_TERMS,
      quote_details: quote_details.to_json
    }
    first_params_hash = params_hash.deep_dup
    first_params_hash[:quote_details] = SAMPLE_QUOTE_DETAILS.to_json
    post :new_quote_for_property, first_params_hash
    post :new, params_hash
    assert_response 200

    quote = Agents::Branches::AssignedAgents::Quote.last
    ### Now lets submit the quote
    post :submit, { udprn: '123456', quote_id: quote.id }
    response = Oj.load(@response.body)
    assert_response 200
    assert_equal response['message'], 'The quote is accepted'
  end

  def test_quotes_per_property
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!

    get :quotes_per_property, { udprn: SAMPLE_UDPRN }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 0

    new_quote_for_property(SAMPLE_UDPRN)
    sleep(3)
    agent_id = Agents::Branches::AssignedAgent.last.id
    new_quote_by_agent(SAMPLE_UDPRN, agent_id)

    get :quotes_per_property, { udprn: SAMPLE_UDPRN }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1

    keys = ["name", "id", "aggregate_stats", "property_quotes", "quote_id"]
    keys.map { |e| assert_includes response.first, e }

    aggregate_keys = ["branch_id", "aggregate_sales", "avg_no_of_days_to_sell", "percent_more_than_valuation", "avg_changes_to_valuation", "avg_increase_in_valuation", "avg_percent_of_first_valuation", "avg_percent_of_final_valuation", "pay_link", "quote_price", "payment_terms"]
    aggregate_keys.map { |e| assert_includes response.first['aggregate_stats'], e }
  end

  def test_quotes_per_property_rent
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    agent.branch_id = branch.id
    branch.district = SAMPLE_DISTRICT
    assert agent.save!
    assert branch.save!
    rent_udprn = '123456'

    get :quotes_per_property, { udprn: rent_udprn }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 0

    new_quote_for_property(rent_udprn)
    sleep(3)
    agent_id = Agents::Branches::AssignedAgent.last.id
    new_quote_by_agent(rent_udprn, agent_id)

    get :quotes_per_property, { udprn: rent_udprn }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response.length, 1

    keys = ["name", "id", "aggregate_stats", "property_quotes", "quote_id"]
    keys.map { |e| assert_includes response.first, e }

    aggregate_keys = ["branch_id", "aggregate_sales", "avg_no_of_days_to_sell", "percent_more_than_valuation", "avg_changes_to_valuation", "avg_increase_in_valuation", "avg_percent_of_first_valuation", "avg_percent_of_final_valuation", "pay_link", "quote_price", "payment_terms"]
    aggregate_keys.map { |e| assert_includes response.first['aggregate_stats'], e }
  end

  ### Test 
  def teardown
    delete_es_address(SAMPLE_UDPRN)
    delete_es_address('123456')
    Event.destroy_all
    Agents::Branches::AssignedAgents::Quote.destroy_all
  end

end