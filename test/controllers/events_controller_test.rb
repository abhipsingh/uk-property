require 'minitest/autorun'
require 'test_helper'

class EventsControllerTest < ActionController::TestCase
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
  SAMPLE_ADDRESS_DOC = {"_index"=>"test_addresses", "_type"=>"test_address", "_id"=>SAMPLE_UDPRN, "_score"=>1.0, "_source"=>{"area"=> SAMPLE_AREA, "building_number"=> SAMPLE_BUILDING_NUMBER, "county"=> SAMPLE_COUNTY, "dependent_locality"=> SAMPLE_DEPENDENT_LOCALITY, "dependent_thoroughfare_description"=>SAMPLE_ROAD, "district"=> SAMPLE_DISTRICT, "hashes"=>["BIRKENHEAD", "Merseyside", "BIRKENHEAD_Birkenhead", "BIRKENHEAD_Birkenhead_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Oxton", "BIRKENHEAD_Oxton_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Prenton", "BIRKENHEAD_Prenton_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Rock Ferry", "BIRKENHEAD_Rock Ferry_Mount Road", "BIRKENHEAD_Rock Ferry_Mount Road_142"], "match_type_str"=>["BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Birkenhead|Normal", "BIRKENHEAD_Birkenhead_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Oxton|Normal", "BIRKENHEAD_Oxton_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Prenton|Normal", "BIRKENHEAD_Prenton_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Rock Ferry|Normal", "BIRKENHEAD_Rock Ferry_Mount Road|Normal", "BIRKENHEAD_Rock Ferry_Mount Road_142|Normal"], "post_code"=>SAMPLE_POSTCODE, "post_town"=>"BIRKENHEAD", "postcode"=>SAMPLE_POSTCODE.split(' ').join(''), "postcode_type"=>"S", "sector"=>SAMPLE_SECTOR, "unit"=>SAMPLE_POSTCODE.split(' ').join(''), "udprn"=>SAMPLE_UDPRN, "vanity_url"=>"6-embers-society-mount-road-birkenhead-merseyside-CH428NN", "photo_urls"=>[], "agent_employee_email_address"=>"b@c.com", "property_style"=>"Don’t know", "epc"=>"No", "receptions"=>nil, "decorative_condition"=>"Needs modernisation", "price_last_updated"=>nil, "total_property_size"=>nil, "agent_employee_mobile_number"=>"9876543210", "assigned_agent_employee_address"=>"5 Bina Gardens", "last_sale_date"=>"2016-06-27", "valuation"=>128000, "floors"=>6, "assigned_agent_employee_name"=>"John Smith", "description"=>nil, "cost_per_month"=>4900, "property_status_type"=>"Green", "year_built"=>"1961-01-01", "listing_type"=>"Basic", "chain_free"=>"Yes", "improvement_spend"=>5557, "price"=>720000, "beds"=>nil, "internal_property_size"=>nil, "street_view_image_url"=>"https://s3-us-west-2.amazonaws.com/propertyuk/11292578_street_view.jpg", "verification_status"=>false, "last_sale_price"=>503999, "last_listing_updated"=>"2 minutes ago", "agent_employee_name"=>"John Clarke", "budget"=>280000, "agent_employee_profile_image"=>"https://st.zoocdn.com/zoopla_static_agent_logo_(44631).data", "outside_space_type"=>"Terrace", "parking_type"=>"Single garage", "central_heating"=>"None", "valuation_date"=>"2016-01-15", "added_by"=>"Us", "date_added"=>"2016-07-31", "broker_branch_contact"=>"020 3641 4259", "additional_features_type"=>["Swimming pool"], "last_sale_price_date"=>"2012-01-14", "floorplan"=>"No", "monitoring_type"=>"No", "time_frame"=>"2012-01-01", "baths"=>nil, "agent_logo"=>nil, "assigned_agent_employee_image"=>nil, "broker_logo"=>nil, "last_updated_date"=>"2015-09-21", "listed_status"=>"Locally listed", "verification_time"=>"2016-06-18 21:32:44", "photos"=>["https://s3-us-west-2.amazonaws.com/propertyuk/11292578_street_view.jpg"], "current_valuation"=>553846, "property_type"=>nil, "agent_branch_name"=>"Dwellings", "address"=>"142, Mount Road, Birkenhead", "date_updated"=>"2017-01-11", "agent_contact"=>"020 3641 4259", "tenure"=>nil, "dream_price"=>720000, "status_last_updated"=>"2016-07-30 21:32:44", "external_property_size"=>nil}}
  SAMPLE_LOCATION_DOC = { "_index"=> "test_locations", "_type"=> "test_location", "_id"=> SAMPLE_HASH, "_score"=> 1, "_source"=> { "hashes"=> SAMPLE_HASH, "suggest"=> { "input"=> [ SAMPLE_TEXT_STR ], "output"=> SAMPLE_TEXT_STR, "weight"=> 10, "payload"=> { "hash"=> SAMPLE_HASH, "hierarchy_str"=> SAMPLE_HIERARCHY, "postcode"=> SAMPLE_POSTCODE, "type"=> "thoroughfare_description" } } } }
  CLIENT = Elasticsearch::Client.new

  def setup
    address_doc = SAMPLE_ADDRESS_DOC.deep_dup
    index_es_address(SAMPLE_UDPRN, address_doc['_source'])
  end


  def test_x
  end


  def teardown
    delete_es_address(SAMPLE_UDPRN)
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

end