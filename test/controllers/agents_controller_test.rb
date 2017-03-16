require 'minitest/autorun'
require 'test_helper'
require_relative '../helpers/es_helper'
require_relative '../helpers/events_helper'
require_relative '../helpers/quotes_helper'
require_relative '../helpers/udprn_helper'
require_relative '../helpers/agents_helper'
# ruby -Itest path/to/tc_file.rb --name test_method_name
class AgentsControllerTest < ActionController::TestCase
  include EsHelper
  include EventsHelper
  include QuotesHelper
  include UdprnHelper
  include AgentsHelper

  def setup
    @address_doc = SAMPLE_ADDRESS_DOC.deep_dup
    index_es_address(SAMPLE_UDPRN, @address_doc['_source'])
    sleep(1)
  end

  def test_search
    agent = Agents::Branches::AssignedAgent.last
    agent.name = 'random name'
    agent.save!
    get :search, { str: 'random name' }
    assert_response 200
    response = Oj.load(@response.body)
    keys = ['Company', 'Branch', 'Group', 'Agent']
    keys.map { |e| assert !response.select{ |t| t['type'] == e }.empty? }
    agent_response = response.select{ |t| t['type'] == 'Agent' }.first['result'].first
    assert_equal agent_response['id'], agent.id

    branch = Agents::Branch.last
    branch.name = 'random name 2'
    branch.save!
    get :search, { str: 'random name 2' }
    assert_response 200
    response = Oj.load(@response.body)
    agent_response = response.select{ |t| t['type'] == 'Branch' }.first['result'].first
    assert_equal agent_response['id'], branch.id

    company = Agent.last
    company.name = 'random name 3'
    company.save!
    get :search, { str: 'random name 3' }
    assert_response 200
    response = Oj.load(@response.body)
    agent_response = response.select{ |t| t['type'] == 'Company' }.first['result'].first
    assert_equal agent_response['id'], company.id

    group = Agents::Group.last
    group.name = 'random name 4'
    group.save!
    get :search, { str: 'random name 4' }
    assert_response 200
    response = Oj.load(@response.body)
    agent_response = response.select{ |t| t['type'] == 'Group' }.first['result'].first
    assert_equal agent_response['id'], group.id
  end

  def test_info_agents
    get :info_agents, { udprn: SAMPLE_UDPRN }
    assert_response 200
    prev_count = Oj.load(@response.body)
    response = get_es_address(SAMPLE_UDPRN)
    district = response['_source']['district']
    branch = Agents::Branch.last
    agent = Agents::Branches::AssignedAgent.last
    branch.district = district
    branch.save!
    agent.branch_id = branch.id
    agent.save!

    get :info_agents, { udprn: SAMPLE_UDPRN }
    assert_response 200
    response = Oj.load(@response.body)
    assert_equal response, prev_count + 1
  end

  def test_assigned_agent_details
    link_agent_hierarchy
    get :assigned_agent_details, { assigned_agent_id: Agents::Branches::AssignedAgent.last.id }
    assert_response 200
    response = Oj.load(@response.body)
    keys = ['id', 'name', 'email', 'mobile', 'branch_id', 'title', 'office_phone_number',
            'mobile_phone_number', 'image_url', 'invited_agents', 'active_properties', 
            'company_id', 'group_id']
    assert_equal response.keys.sort, keys.sort
    assert_equal response['id'], Agents::Branches::AssignedAgent.last.id
  end

  def test_branch_details
    link_agent_hierarchy
    get :branch_details, { branch_id: Agents::Branch.last.id }
    assert_response 200
    response = Oj.load(@response.body)
    keys = ["address", "agent_id", "company_id", "district", "email", "group_id", "id", "image_url", "invited_agents", "name", "phone_number", "postcode", "property_urls", "udprns", "website", "assigned_agents"]
    assert_equal keys.sort, response.keys.sort
    assert_equal response['id'], Agents::Branch.last.id
  end

  def test_company_details
    link_agent_hierarchy
    get :company_details, { company_id: Agent.last.id }
    assert_response 200
    response = Oj.load(@response.body)
    # p response.keys.sort
    keys = ["address", "branches", "branches_url", "email", "group_id", "id", "image_url", "name", "phone_number", "website"]
    assert_equal response.keys.sort, keys
    assert_equal response['id'], Agent.last.id
  end

  def test_group_details
    link_agent_hierarchy
    get :group_details, { group_id: Agents::Group.last.id }
    assert_response 200
    response = Oj.load(@response.body)
    # p response.keys.sort
    keys = ["address", "companies", "created_at", "email", "id", "image_url", "name", "phone_number", "updated_at", "website"]
    assert_equal response.keys.sort, keys
    assert_equal response['id'], Agents::Group.last.id
  end

  ### Test 
  def teardown
    delete_es_address(SAMPLE_UDPRN)
    # Event.destroy_all
    # Agents::Branches::AssignedAgent.destroy_all
  end

end