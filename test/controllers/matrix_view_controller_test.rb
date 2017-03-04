require 'minitest/autorun'
require 'test_helper'

class MatrixViewControllerTest < ActionController::TestCase
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
  SAMPLE_HIERARCHY = "Douglas Road|LIVERPOOL|Merseyside"
  SAMPLE_DEPENDENT_LOCALITY = "Birkenhead"
  SAMPLE_ROAD = 'Mount Road'
  SAMPLE_ADDRESS_DOC = {"_index"=>"test_addresses", "_type"=>"test_address", "_id"=>"4705449", "_score"=>1.0, "_source"=>{"area"=> SAMPLE_AREA, "building_number"=> SAMPLE_BUILDING_NUMBER, "county"=> SAMPLE_COUNTY, "dependent_locality"=> SAMPLE_DEPENDENT_LOCALITY, "dependent_thoroughfare_description"=>SAMPLE_ROAD, "district"=> SAMPLE_DISTRICT, "hashes"=>["BIRKENHEAD", "Merseyside", "BIRKENHEAD_Birkenhead", "BIRKENHEAD_Birkenhead_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Oxton", "BIRKENHEAD_Oxton_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Prenton", "BIRKENHEAD_Prenton_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Rock Ferry", "BIRKENHEAD_Rock Ferry_Mount Road", "BIRKENHEAD_Rock Ferry_Mount Road_142"], "match_type_str"=>["BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Birkenhead|Normal", "BIRKENHEAD_Birkenhead_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Oxton|Normal", "BIRKENHEAD_Oxton_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Prenton|Normal", "BIRKENHEAD_Prenton_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Rock Ferry|Normal", "BIRKENHEAD_Rock Ferry_Mount Road|Normal", "BIRKENHEAD_Rock Ferry_Mount Road_142|Normal"], "post_code"=>SAMPLE_POSTCODE, "post_town"=>"BIRKENHEAD", "postcode"=>SAMPLE_POSTCODE.split(' ').join(''), "postcode_type"=>"S", "sector"=>SAMPLE_SECTOR, "suggest"=>{"input"=>["CH428NN"], "output"=>"CH42 8NN"}, "udprn"=>SAMPLE_POSTCODE.split(' ').join(''), "unit"=>"CH428NN", "vanity_url"=>"142-mount-road-birkenhead|oxton|prenton|rock-ferry-birkenhead-merseyside-CH428NN", "photo_urls"=>[], "agent_employee_email_address"=>"b@c.com", "property_style"=>"Don’t know", "epc"=>"No", "receptions"=>nil, "decorative_condition"=>"Needs modernisation", "price_last_updated"=>nil, "total_property_size"=>nil, "agent_employee_mobile_number"=>"9876543210", "assigned_agent_employee_address"=>"5 Bina Gardens", "last_sale_date"=>"2016-06-27", "valuation"=>128000, "floors"=>6, "assigned_agent_employee_name"=>"John Smith", "description"=>nil, "cost_per_month"=>4900, "property_status_type"=>"Green", "year_built"=>"1961-01-01", "listing_type"=>"Basic", "chain_free"=>"Yes", "improvement_spend"=>5557, "price"=>720000, "beds"=>nil, "internal_property_size"=>nil, "street_view_image_url"=>"https://s3-us-west-2.amazonaws.com/propertyuk/11292578_street_view.jpg", "verification_status"=>false, "last_sale_price"=>503999, "last_listing_updated"=>"2 minutes ago", "agent_employee_name"=>"John Clarke", "budget"=>280000, "agent_employee_profile_image"=>"https://st.zoocdn.com/zoopla_static_agent_logo_(44631).data", "outside_space_type"=>"Terrace", "parking_type"=>"Single garage", "central_heating"=>"None", "valuation_date"=>"2016-01-15", "added_by"=>"Us", "date_added"=>"2016-07-31", "broker_branch_contact"=>"020 3641 4259", "additional_features_type"=>["Swimming pool"], "last_sale_price_date"=>"2012-01-14", "floorplan"=>"No", "monitoring_type"=>"No", "time_frame"=>"2012-01-01", "baths"=>nil, "agent_logo"=>nil, "assigned_agent_employee_image"=>nil, "broker_logo"=>nil, "last_updated_date"=>"2015-09-21", "listed_status"=>"Locally listed", "verification_time"=>"2016-06-18 21:32:44", "photos"=>["https://s3-us-west-2.amazonaws.com/propertyuk/11292578_street_view.jpg"], "current_valuation"=>553846, "property_type"=>nil, "agent_branch_name"=>"Dwellings", "address"=>"142, Mount Road, Birkenhead", "date_updated"=>"2017-01-11", "agent_contact"=>"020 3641 4259", "tenure"=>nil, "dream_price"=>720000, "status_last_updated"=>"2016-07-30 21:32:44", "external_property_size"=>nil}}
  SAMPLE_LOCATION_DOC = { "_index"=> "test_locations", "_type"=> "test_location", "_id"=> SAMPLE_HASH, "_score"=> 1, "_source"=> { "hashes"=> SAMPLE_HASH, "suggest"=> { "input"=> [ SAMPLE_TEXT_STR ], "output"=> SAMPLE_TEXT_STR, "weight"=> 10, "payload"=> { "hash"=> SAMPLE_HASH, "hierarchy_str"=> SAMPLE_HIERARCHY, "postcode"=> SAMPLE_POSTCODE, "type"=> "thoroughfare_description" } } } }
  CLIENT = Elasticsearch::Client.new
  def setup
    @id = SAMPLE_ADDRESS_DOC['_id']
    @location_id = SAMPLE_HASH
    create_location_doc(@location_id, SAMPLE_LOCATION_DOC['_source'].clone)
    sleep 2
  end

  def test_predictive_search
    get :predictive_search, str: SAMPLE_TEXT_STR
    assert_response 200
    response = Oj.load(@response.body)
    refute_empty response
    assert_includes response.first, 'hash'
    assert_includes response.first, 'output'
    assert_equal response.first['hash'], SAMPLE_HASH
    assert_equal response.first['output'], SAMPLE_OUTPUT
    # assert_includes @post.title, @response.body
  end


  def test_matrix_view_thoroughfare_description
    get :matrix_view, str: 'douglas road liverpool'
    response = Oj.load(@response.body)
    assert_includes response, 'type'
    assert_includes response, 'dependent_thoroughfare_descriptions'
    assert_includes response, 'dependent_localities'
    assert_includes response, 'districts'
    assert_includes response, 'post_towns'
    assert_includes response, 'units'
    assert_includes response, 'sectors'
    assert_includes response, 'areas'
    assert_includes response, 'counties'

    sample_val = SAMPLE_ADDRESS_DOC
    new_address = sample_val['_source'].clone
    new_address['thoroughfare_description'] = SAMPLE_THOROUGHFARE_DESCRIPTOR
    new_address['county'] = SAMPLE_COUNTY
    new_address['post_town'] = SAMPLE_POST_TOWN
    new_address['area'] = SAMPLE_AREA
    new_address['district'] = SAMPLE_DISTRICT
    new_address['udprn'] = @id
    hashes = new_address['hashes']
    match_type_str = new_address['match_type_str']
    match_type_str.push(SAMPLE_HASH+'|Normal')
    hashes.push(SAMPLE_HASH)
    new_address['hashes'] = hashes
    new_address['match_type_str'] = match_type_str
    index_es_address(@id, new_address)
    sleep 1
    get :matrix_view, str: 'douglas road liverpool'
    response = Oj.load(@response.body)
    include_keys = ['dependent_thoroughfare_descriptions', 'type', 'thoroughfare_descriptions', 'dependent_localities',
                    'districts', 'post_towns', 'units', 'sectors', 'areas', 'counties', 'thoroughfare_description', 'county',
                    'post_town', 'unit', 'district', 'dependent_locality', 'dependent_thoroughfare_description', 'sector']
    include_keys.map { |e|  assert_includes response, e }

    p response

    assert_response 200
    delete_es_address(@id)
  end

  def test_matrix_view_building_type
    building_hash = SAMPLE_LOCATION_DOC['_source'].deep_dup
    building_hash['suggest']['payload']['type'] = 'building_type'
    building_hash['suggest']['input'] =  [ (SAMPLE_BUILDING_NAME.downcase+' ' + building_hash['suggest']['input'].first) ]
    building_hash['hashes'] = SAMPLE_HASH + '_' + SAMPLE_BUILDING_NAME
    building_hash['suggest']['payload']['hash'] =  SAMPLE_HASH + '_' + SAMPLE_BUILDING_NAME
    location_id_1 = SAMPLE_BUILDING_NAME + @location_id
    create_location_doc(location_id_1, building_hash)
    sleep(1)
    get :matrix_view, str: building_hash['suggest']['input'].first
    assert_response 200
    sample_val = SAMPLE_ADDRESS_DOC
    new_address = sample_val['_source'].deep_dup
    new_address['thoroughfare_description'] = SAMPLE_THOROUGHFARE_DESCRIPTOR
    new_address['udprn'] = @id
    hashes = new_address['hashes']
    match_type_str = new_address['match_type_str']
    match_type_str.push(building_hash['suggest']['payload']['hash']+'|Normal')
    hashes.push(building_hash['suggest']['payload']['hash'])
    new_address['hashes'] = hashes
    new_address['match_type_str'] = match_type_str
    index_es_address(@id, new_address)
    sleep(3)
    get :matrix_view, str: building_hash['suggest']['input'].first
    response = Oj.load(@response.body)
    include_keys = ['dependent_thoroughfare_descriptions', 'type', 'thoroughfare_descriptions', 'dependent_localities',
                    'districts', 'post_towns', 'units', 'sectors', 'areas', 'counties', 'thoroughfare_description', 'county',
                    'post_town', 'unit', 'district', 'dependent_locality', 'dependent_thoroughfare_description', 'sector']
    include_keys.map { |e|  assert_includes response, e }

    p response

    assert_response 200
    delete_es_address(@id)
    destroy_location_doc(location_id_1)
  end

  def test_matrix_view_street
    street_hash = SAMPLE_LOCATION_DOC['_source'].deep_dup
    street_hash['suggest']['payload']['type'] = 'dependent_thoroughfare_description'
    text_str = SAMPLE_ROAD.downcase+' '+SAMPLE_DEPENDENT_LOCALITY.downcase+' '+SAMPLE_POST_TOWN.downcase
    street_hash['suggest']['input'] = [ text_str ]
    hash_val = SAMPLE_POST_TOWN+'_'+SAMPLE_DEPENDENT_LOCALITY+'_'+SAMPLE_ROAD
    street_hash['suggest']['payload']['hash'] = hash_val
    create_location_doc(hash_val, street_hash)
    sleep(1)
    get :matrix_view, str: text_str

    assert_response 200
    sample_val = SAMPLE_ADDRESS_DOC
    new_address = sample_val['_source'].deep_dup
    new_address['dependent_thoroughfare_descriptions'] = SAMPLE_ROAD
    new_address['thoroughfare_description'] = SAMPLE_THOROUGHFARE_DESCRIPTOR
    new_address['udprn'] = @id
    hashes = new_address['hashes']
    match_type_str = new_address['match_type_str']
    match_type_str.push(street_hash['suggest']['payload']['hash']+'|Normal')
    hashes.push(street_hash['suggest']['payload']['hash'])
    new_address['hashes'] = hashes
    new_address['match_type_str'] = match_type_str
    index_es_address(@id, new_address)
    sleep(3)
    get :matrix_view, str: street_hash['suggest']['input'].first
    response = Oj.load(@response.body)
    p response
    destroy_location_doc(hash_val)
    delete_es_address(@id)
  end

  def test_matrix_view_locality
    locality_hash = SAMPLE_LOCATION_DOC['_source'].deep_dup
    locality_hash['suggest']['payload']['type'] = 'dependent_locality'
    text_str = SAMPLE_DEPENDENT_LOCALITY.downcase+' '+SAMPLE_POST_TOWN.downcase
    locality_hash['suggest']['input'] = [ text_str ]
    hash_val = SAMPLE_POST_TOWN+'_'+SAMPLE_DEPENDENT_LOCALITY
    locality_hash['suggest']['payload']['hash'] = hash_val
    create_location_doc(hash_val, locality_hash)
    sleep(1)
    get :matrix_view, str: text_str

    assert_response 200
    sample_val = SAMPLE_ADDRESS_DOC
    new_address = sample_val['_source'].deep_dup
    new_address['dependent_locality'] = SAMPLE_DEPENDENT_LOCALITY
    new_address['thoroughfare_description'] = SAMPLE_THOROUGHFARE_DESCRIPTOR
    new_address['udprn'] = @id
    hashes = new_address['hashes']
    match_type_str = new_address['match_type_str']
    match_type_str.push(locality_hash['suggest']['payload']['hash']+'|Normal')
    hashes.push(locality_hash['suggest']['payload']['hash'])
    new_address['hashes'] = hashes
    new_address['match_type_str'] = match_type_str
    index_es_address(@id, new_address)
    sleep(3)
    get :matrix_view, str: locality_hash['suggest']['input'].first
    response = Oj.load(@response.body)
    p response
    destroy_location_doc(hash_val)
    delete_es_address(@id)
  end

  def test_matrix_view_post_town
    post_town_hash = SAMPLE_LOCATION_DOC['_source'].deep_dup
    post_town_hash['suggest']['payload']['type'] = 'post_town'
    text_str = SAMPLE_POST_TOWN.downcase
    post_town_hash['suggest']['input'] = [ text_str ]
    hash_val = SAMPLE_POST_TOWN
    post_town_hash['suggest']['payload']['hash'] = hash_val
    post_town_hash['suggest']['payload']['county'] = SAMPLE_COUNTY
    post_town_hash['hashes'] = hash_val
    create_location_doc(hash_val, post_town_hash)
    sleep(1)
    get :matrix_view, str: text_str
    p Oj.load(@response.body)
    assert_response 200
    sample_val = SAMPLE_ADDRESS_DOC
    new_address = sample_val['_source'].deep_dup
    new_address['post_town'] = SAMPLE_POST_TOWN
    new_address['thoroughfare_description'] = SAMPLE_THOROUGHFARE_DESCRIPTOR
    new_address['udprn'] = @id
    hashes = new_address['hashes']
    match_type_str = new_address['match_type_str']
    match_type_str.push(post_town_hash['suggest']['payload']['hash']+'|Normal')
    hashes.push(post_town_hash['suggest']['payload']['hash'])
    new_address['hashes'] = hashes
    new_address['match_type_str'] = match_type_str
    index_es_address(@id, new_address)
    sleep(3)
    get :matrix_view, str: post_town_hash['suggest']['input'].first
    response = Oj.load(@response.body)
    p response
    destroy_location_doc(hash_val)
    delete_es_address(@id)
  end

  def test_matrix_view_county
    county_hash = SAMPLE_LOCATION_DOC['_source'].deep_dup
    county_hash['suggest']['payload']['type'] = 'county'
    text_str = SAMPLE_COUNTY.downcase
    county_hash['suggest']['input'] = [ text_str ]
    hash_val = SAMPLE_COUNTY
    county_hash['suggest']['payload']['hash'] = hash_val
    county_hash['suggest']['payload']['county'] = SAMPLE_COUNTY
    county_hash['hashes'] = hash_val
    create_location_doc(hash_val, county_hash)
    sleep(1)
    get :matrix_view, str: text_str
    p Oj.load(@response.body)
    assert_response 200
    sample_val = SAMPLE_ADDRESS_DOC
    new_address = sample_val['_source'].deep_dup
    new_address['county'] = SAMPLE_COUNTY
    new_address['thoroughfare_description'] = SAMPLE_THOROUGHFARE_DESCRIPTOR
    new_address['udprn'] = @id
    hashes = new_address['hashes']
    match_type_str = new_address['match_type_str']
    match_type_str.push(county_hash['suggest']['payload']['hash']+'|Normal')
    hashes.push(county_hash['suggest']['payload']['hash'])
    new_address['hashes'] = hashes
    new_address['match_type_str'] = match_type_str
    index_es_address(@id, new_address)
    sleep(3)
    get :matrix_view, str: county_hash['suggest']['input'].first
    response = Oj.load(@response.body)
    p response
    destroy_location_doc(hash_val)
    delete_es_address(@id)
  end


  def index_es_address(id, body)
    CLIENT.index index: Rails.configuration.address_index_name,
                 type: Rails.configuration.address_type_name,
                 id: id,
                 body: body
  end

  def delete_es_address(id)
    CLIENT.delete index: Rails.configuration.address_index_name,
                  type: Rails.configuration.address_type_name,
                  id: id
  end

  def create_location_doc(id, body)
    CLIENT.index index: Rails.configuration.location_index_name,
                 type: Rails.configuration.location_type_name,
                 id: id,
                 body: body
  end

  def destroy_location_doc(id)
     CLIENT.delete index: Rails.configuration.location_index_name,
                   type: Rails.configuration.location_type_name,
                   id: id
  end

  def teardown
    # destroy_location_doc(@location_id)
  end




end