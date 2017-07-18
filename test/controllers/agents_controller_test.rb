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

  def test_add_agent_details
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    branch = agent.branch
    verification_hash = branch.verification_hash
    request_hash = {
      branch_id: branch.id,
      verification_hash: verification_hash,
      branch_name: "Random name",
      branch_address: "Random address",
      branch_email: "a@b.com",
      branch_phone_number: 9829301823,
      branch_website: 'www.ggg.com',
      group_name: "Random name",
      company_name: "Random name"
    }
    post :add_agent_details, request_hash
    assert_response 201
  end


  def test_invite_agents_to_register
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    request_hash = {
      branch_id: agent.branch_id,
      invited_agents: [{ branch_id: agent.branch_id, company_id: agent.branch.agent_id, email: 'test@prophety.co.uk' }].to_json
    }
    post :invite_agents_to_register, request_hash
    assert_response 200
  end

  def test_edit
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    branch = agent.branch
    random_str = 'random str'
    request_hash = {
      name: random_str,
      email: "a@b.com",
      title: random_str,
      mobile: random_str,
      image_url: random_str,
      password: '123456789',
      office_phone_number: random_str,
      mobile_phone_number: random_str
    }
    post :edit, { agent: request_hash, id: agent.id }
    assert_response 200
    agent = Agents::Branches::AssignedAgent.last
    assert_equal agent.name, random_str
    assert_equal agent.email, 'a@b.com'
    assert_equal agent.title, random_str
    assert_equal agent.mobile, random_str
    assert_equal agent.image_url, random_str
    assert_equal agent.office_phone_number, random_str
    assert_equal agent.mobile_phone_number, random_str
  end

  def test_invite_vendor
    link_agent_hierarchy
    vendor = Vendor.last
    udprn = SAMPLE_UDPRN
    agent_id = Agents::Branches::AssignedAgent.last.id
    post :invite_vendor, { udprn: udprn, agent_id: agent_id, vendor_email: 'test@prophety.co.uk' }
    assert_response 200
  end

  def test_verify_agent
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    request_hash = {
      udprn: SAMPLE_UDPRN,
      agent_id: agent.id
    }
    post :verify_agent, request_hash
    assert_response 200
    doc = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal doc['agent_id'], agent.id
    assert doc['verification_status']
    assert_equal doc['property_status_type'], 'Green'
    # assert_equal doc['']

    request_hash[:property_for] = 'Rent'
    post :verify_agent, request_hash
    assert_response 200
    doc = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal doc['agent_id'], agent.id
    assert doc['verification_status']
    assert_equal doc['property_status_type'], 'Rent'
  end

  def test_verify_property_through_agent
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    request_hash = {
      property_type: SAMPLE_PROPERTY_TYPE,
      beds: 34,
      baths: 23,
      receptions: 23,
      property_id: 12344,
      agent_id: agent.id,
      vendor_email: 'test@prophety.co.uk',
      assigned_agent_email: agent.email,
      udprn: SAMPLE_UDPRN
    }
    post :verify_property_through_agent, request_hash
    assert_response 200
    doc = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal doc['agent_id'], agent.id
    assert_equal doc['verification_status'], false
    assert_equal doc['property_status_type'], 'Green'
    assert_equal doc['property_type'], SAMPLE_PROPERTY_TYPE
    assert_equal doc['beds'], 34
    assert_equal doc['baths'], 23
    assert_equal doc['receptions'], 23

    ## For rent
    request_hash[:property_for] = 'Rent'
    post :verify_property_through_agent, request_hash
    doc = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal doc['property_status_type'], 'Rent'
  end

  def test_verify_property_from_vendor
    link_agent_hierarchy
    post :verify_property_from_vendor, { verified: true, udprn: SAMPLE_UDPRN }
    assert_response 200
    doc = get_es_address(SAMPLE_UDPRN)['_source']
    assert doc['verification_status']
    assert_response 200
  end

  def test_verify_manual_property_from_agent
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    request_hash = {
      property_type: SAMPLE_PROPERTY_TYPE,
      beds: 34,
      baths: 23,
      receptions: 23,
      agent_id: agent.id,
      vendor_email: 'test@prophety.co.uk',
      assigned_agent_email: agent.email,
      udprn: SAMPLE_UDPRN
    }
    post :verify_manual_property_from_agent, request_hash
    assert_response 200
    doc = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal doc['agent_id'], agent.id
    assert_equal doc['verification_status'], false
    assert_equal doc['property_status_type'], 'Green'
    assert_equal doc['property_type'], SAMPLE_PROPERTY_TYPE
    assert_equal doc['beds'], 34
    assert_equal doc['baths'], 23
    assert_equal doc['receptions'], 23

     ## For rent
    request_hash[:property_for] = 'Rent'
    post :verify_manual_property_from_agent, request_hash
    doc = get_es_address(SAMPLE_UDPRN)['_source']
    assert_equal doc['property_status_type'], 'Rent'
  end

  def test_verify_udprn_to_crawled_property
    agent = Agents::Branches::AssignedAgent.last
    crawled_property = Agents::Branches::CrawledProperty.last
    crawled_property.branch_id = agent.branch_id
    crawled_property.postcode = SAMPLE_POSTCODE.split(' ').join('')
    crawled_property.save!
    get :verify_udprn_to_crawled_property, { id: agent.id }
    response = Oj.load(@response.body)
    assert_equal response['response'].length, 1
    assert ( response['response'][0]['matching_properties'].length > 0 )
  end

  def test_edit_branch_details
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    branch = agent.branch
    sample_str = 'sample str'
    request_hash = {
      id: branch.id,
      branch: {
        name: sample_str,
        address: sample_str,
        phone_number: sample_str,
        website: sample_str,
        image_url: sample_str,
        email: sample_str
      }
    }
    post :edit_branch_details, request_hash
    assert_response 200
    branch = Agents::Branch.find(branch.id)
    assert_equal branch.name, sample_str
    assert_equal branch.address, sample_str
    assert_equal branch.phone_number, sample_str
    assert_equal branch.website, sample_str
    assert_equal branch.image_url, sample_str
    assert_equal branch.email, sample_str
  end

  def test_edit_company_details
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    branch = agent.branch
    sample_str = 'sample str'
    request_hash = {
      id: branch.agent_id,
      company: {
        name: sample_str,
        address: sample_str,
        phone_number: sample_str,
        website: sample_str,
        image_url: sample_str,
        email: sample_str
      }
    }
    post :edit_company_details, request_hash
    assert_response 200
    company = Agents::Branch.find(branch.id).agent
    assert_equal company.name, sample_str
    assert_equal company.address, sample_str
    assert_equal company.phone_number, sample_str
    assert_equal company.website, sample_str
    assert_equal company.image_url, sample_str
    assert_equal company.email, sample_str
  end

  def test_edit_group_details
    link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    group = agent.branch.agent.group
    sample_str = 'sample str'
    request_hash = {
      id: group.id,
      group: {
        name: sample_str,
        address: sample_str,
        phone_number: sample_str,
        website: sample_str,
        image_url: sample_str,
        email: sample_str
      }
    }
    post :edit_group_details, request_hash
    assert_response 200
    group = Agents::Branches::AssignedAgent.last.branch.agent.group
    assert_equal group.name, sample_str
    assert_equal group.address, sample_str
    assert_equal group.phone_number, sample_str
    assert_equal group.website, sample_str
    assert_equal group.image_url, sample_str
    assert_equal group.email, sample_str
  end

  ### Test 
  def teardown
    delete_es_address(SAMPLE_UDPRN)
    # Event.destroy_all
    # Agents::Branches::AssignedAgent.destroy_all
  end

end