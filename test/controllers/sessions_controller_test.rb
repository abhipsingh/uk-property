require 'minitest/autorun'
require './test/test_helper'

class SessionsControllerTest < ActionController::TestCase
  
  def setup
    @test_agent_email = "liverpoolagent1@test.com"
    @test_vendor_email = "liverpoolvendor1@test.com"
    @test_buyer_email = "buyer8@test1.com"
    @test_password = "1234567890"
    @test_name = "Test Vendor"
  end

  def test_create_agent
    random_email_string = ('a'..'z').to_a.shuffle[0,8].join
    post :create_agent, {agent: {email: random_email_string, password: @test_password, branch_id: 0000}}
    assert_response 200
    # Rails.logger.info ("response = #{response.body.inspect}")
    response_hash = JSON.parse(response.body)
    # Rails.logger.info ("response = #{response_hash['auth_token'].inspect}")
    assert_not_nil response_hash['auth_token']
    assert_not_nil response_hash['details']
    # assert_includes response, 'details'
  end

  def test_login_agent
    post :create_agent, {agent: {email: @test_buyer_email, password: @test_password, branch_id: 0000}}
    post :login_agent, {agent: {email: @test_buyer_email, password: @test_password, branch_id: 0000}}
    assert_response 200
    response_hash = JSON.parse(response.body)
    assert_not_nil response_hash['auth_token']
  end

  def test_agent_details
    post :create_agent, {agent: {email: @test_agent_email, password: @test_password, branch_id: 0000}}
    post :login_agent, {agent: {email: @test_agent_email, password: @test_password, branch_id: 0000}}
    response_hash = JSON.parse(response.body)
    
    auth_token = response_hash['auth_token']
    request.headers['AUTHORIZATION'] = auth_token
    get :agent_details
    assert_response 200
  end

  def test_create_vendor
    random_email_string = ('a'..'z').to_a.shuffle[0,8].join
    post :create_vendor, { vendor: {email: random_email_string, password: @test_password , name: @test_name} }
    assert_response 200
    response_hash = JSON.parse(response.body)
    assert_not_nil response_hash['auth_token']
    assert_not_nil response_hash['details']
  end

  def test_login_vendor
    post :create_vendor, {vendor: {email: @test_vendor_email, password: @test_password, name: @test_name}}
    post :login_vendor, {vendor: {email: @test_vendor_email, password: @test_password}}
    assert_response 200
    response_hash = JSON.parse(response.body)
    assert_not_nil response_hash['auth_token']
  end

  def test_vendor_details
    post :create_vendor, {vendor: {email: @test_vendor_email, password: @test_password, name: @test_name}}
    post :login_vendor, {vendor: {email: @test_vendor_email, password: @test_password}}
    response_hash = JSON.parse(response.body)
    
    auth_token = response_hash['auth_token']
    request.headers['authorization'] = auth_token
    get :vendor_details
    assert_response 200
  end

  def test_create_buyer
    random_email_string = ('a'..'z').to_a.shuffle[0,8].join
    post :create_buyer, { buyer: {email: random_email_string, password: @test_password , name: @test_name} }
    assert_response 200
    response_hash = JSON.parse(response.body)
    assert_not_nil response_hash['details']
  end

  def test_login_buyer
    post :create_buyer, {buyer: {email: @test_buyer_email, password: @test_password, name: @test_name}}
    post :login_buyer, {buyer: {email: @test_buyer_email, password: @test_password}}
    assert_response 200
    response_hash = JSON.parse(response.body)
    assert_not_nil response_hash['auth_token']
  end

  def test_buyer_details
    post :create_buyer, {buyer: {email: @test_buyer_email, password: @test_password, name: @test_name}}
    post :login_buyer, {buyer: {email: @test_buyer_email, password: @test_password}}
    response_hash = JSON.parse(response.body)
    
    auth_token = response_hash['auth_token']
    request.headers['AUTHORIZATION'] = auth_token
    get :buyer_details
    assert_response 200
  end

  def test_buyer_signup
    post :buyer_signup, {email: @test_buyer_email}
    assert_response 200
  end

  def test_vendor_signup
    post :vendor_signup, {email: @test_vendor_email}
    assert_response 200
  end

end