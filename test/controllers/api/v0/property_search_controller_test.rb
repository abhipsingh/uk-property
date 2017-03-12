require 'minitest/autorun'
require 'test_helper'
require_relative '../../../helpers/es_helper'

module Api
  module V0
    class PropertySearchControllerTest < ActionController::TestCase
      include EsHelper
      
      SAMPLE_TEXT_STR = 'douglas road liverpool'
      SAMPLE_HASH = 'BIRKENHEAD_Birkenhead'
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
      SAMPLE_BEDS = 3
      SAMPLE_BATHS = 3
      SAMPLE_RECEPTIONS = 2
      SAMPLE_UDPRN = "4705449"
      SAMPLE_ADDRESS_DOC = {
        "_index"=>"test_addresses",
        "_type"=>"test_address",
        "_id"=>"4705449",
        "_score"=>1.0,
        "_source"=> {
          "area"=> SAMPLE_AREA,
          "building_name" => SAMPLE_BUILDING_NAME,
          "building_number"=> SAMPLE_BUILDING_NUMBER,
          "sub_building_name" => "Ember Society",
          "county"=> SAMPLE_COUNTY,
          "dependent_locality"=> SAMPLE_DEPENDENT_LOCALITY,
          "dependent_thoroughfare_description"=>SAMPLE_ROAD,
          "district"=> SAMPLE_DISTRICT,
          "hashes"=>["BIRKENHEAD", "Merseyside", "BIRKENHEAD_Birkenhead", "BIRKENHEAD_Birkenhead_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Oxton", "BIRKENHEAD_Oxton_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Prenton", "BIRKENHEAD_Prenton_Mount Road", "BIRKENHEAD", "Merseyside", "BIRKENHEAD_Rock Ferry", "BIRKENHEAD_Rock Ferry_Mount Road", "BIRKENHEAD_Rock Ferry_Mount Road_142"],
          "match_type_str"=>["BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Birkenhead|Normal", "BIRKENHEAD_Birkenhead_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Oxton|Normal", "BIRKENHEAD_Oxton_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Prenton|Normal", "BIRKENHEAD_Prenton_Mount Road|Normal", "BIRKENHEAD|Normal", "Merseyside|Normal", "BIRKENHEAD_Rock Ferry|Normal", "BIRKENHEAD_Rock Ferry_Mount Road|Normal", "BIRKENHEAD_Rock Ferry_Mount Road_142|Normal"],
          "post_code"=>SAMPLE_POSTCODE,
          "post_town"=>"BIRKENHEAD",
          "postcode"=>SAMPLE_POSTCODE.split(' ').join(''),
          "postcode_type"=>"S",
          "sector"=>SAMPLE_SECTOR,
          "suggest"=> {
            "input"=>["CH428NN"],
            "output"=>"CH42 8NN"
          },
          "udprn"=>SAMPLE_UDPRN,
          "unit"=>"CH428NN",
          "vanity_url"=>"142-mount-road-birkenhead|oxton|prenton|rock-ferry-birkenhead-merseyside-CH428NN",
          "photo_urls"=>[],
          "agent_employee_email_address"=>"b@c.com",
          "property_style"=>"Period",
          "epc"=>"No",
          "receptions"=>SAMPLE_RECEPTIONS,
          "decorative_condition"=>"Excellent",
          "price_last_updated"=>nil,
          "total_property_size"=>7000,
          "agent_employee_mobile_number"=>"9876543210",
          "assigned_agent_employee_address"=>"5 Bina Gardens",
          "last_sale_date"=>"2016-06-27",
          "valuation"=>128000,
          "floors"=>6,
          "assigned_agent_employee_name"=>"John Smith",
          "description"=>nil,
          "cost_per_month"=>4900,
          "property_status_type"=>"Green",
          "year_built"=>"1961-01-01",
          "listing_type"=>"Basic",
          "chain_free"=>"Yes",
          "improvement_spend"=>5557,
          "price"=>720000,
          "beds"=>SAMPLE_BEDS,
          "internal_property_size"=>6789,
          "street_view_image_url"=>"https://s3-us-west-2.amazonaws.com/propertyuk/11292578_street_view.jpg",
          "verification_status"=>false,
          "last_sale_price"=>503999,
          "last_listing_updated"=>"2 minutes ago",
          "agent_employee_name"=>"John Clarke",
          "budget"=>280000,
          "agent_employee_profile_image"=>"https://st.zoocdn.com/zoopla_static_agent_logo_(44631).data",
          "outside_space_type"=>"Terrace",
          "parking_type"=>"Underground",
          "central_heating"=>"None",
          "valuation_date"=>"2016-01-15",
          "added_by"=>"Us",
          "date_added"=>"2016-07-31",
          "broker_branch_contact"=>"020 3641 4259",
          "additional_features_type"=>["Swimming pool"],
          "last_sale_price_date"=>"2012-01-14",
          "floorplan"=>"No",
          "monitoring_type"=>"No",
          "time_frame"=>"2012-01-01",
          "baths"=>SAMPLE_BATHS,
          "agent_logo"=>nil,
          "assigned_agent_employee_image"=>nil,
          "broker_logo"=>nil,
          "last_updated_date"=>"2015-09-21",
          "listed_status"=>"None",
          "verification_time"=>"2016-06-18 21:32:44",
          "photos"=>[
            "https://s3-us-west-2.amazonaws.com/propertyuk/11292578_street_view.jpg"
          ],
          "current_valuation"=>553846,
          "property_type"=>"Bungalow",
          "agent_branch_name"=>"Dwellings",
          "address"=>"142, Mount Road, Birkenhead",
          "date_updated"=>"2017-01-11",
          "agent_contact"=>"020 3641 4259",
          "tenure"=>"Freehold",
          "dream_price"=>720000,
          "status_last_updated"=>"2016-07-30 21:32:44",
          "external_property_size"=>6889,
          "council_tax_band" => "A",
          "agent_id" => 1,
          "vendor_id" => 1,
          "accepting_quotes" => false
        }
      }
      SAMPLE_LOCATION_DOC = {
        "_index"=> "test_locations",
        "_type"=> "test_location",
        "_id"=> SAMPLE_HASH,
        "_score"=> 1,
        "_source"=> 
          {
            "hashes"=> SAMPLE_HASH,
            "suggest"=> 
              {
                "input"=> [ SAMPLE_TEXT_STR ],
                "output"=> SAMPLE_TEXT_STR,
                "weight"=> 10,
                "payload"=> 
                  {
                    "hash"=> SAMPLE_HASH,
                    "hierarchy_str"=> SAMPLE_HIERARCHY,
                    "postcode"=> SAMPLE_POSTCODE,
                    "type"=> "thoroughfare_description" 
                  }
              }
          }
      }

      def setup
        index_es_address(SAMPLE_UDPRN, SAMPLE_ADDRESS_DOC['_source'])
        sleep(1)
      end

      def test_details
        get :details, property_id: SAMPLE_UDPRN
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response["details"]["udprn"], SAMPLE_UDPRN
      end

      def test_search
        ## Property types
        get :search, {property_types: "bungalow"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["property_type"], "Bungalow"

        get :search, {property_types: "flat"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## monitoring types
        get :search, {monitoring_types: "no"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["monitoring_type"], "No"

        get :search, {monitoring_types: "yes"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## property status types
        get :search, {property_status_types: "green"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["property_status_type"], "Green"

        get :search, {property_status_types: "amber"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## parking types
        get :search, {parking_types: "underground"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["parking_type"], "Underground"

        get :search, {parking_types: "single garage"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## outside space type
        get :search, {outside_space_types: "terrace"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["outside_space_type"], "Terrace"

        get :search, {outside_space_types: "private garden"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## additional feature types

        ## keyword types

        ## udprns

        ## vendor ids

        ## postcodes

        ## post_codes

        ################## Term Tests #####################

        # tenure
        get :search, {tenure: "freehold"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["tenure"], "Freehold"

        get :search, {tenure: "leasehold"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## epc
        get :search, {epc: "no"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["epc"], "No"

        get :search, {epc: "yes"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## property style
        get :search, {property_style: "period"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["property_style"], "Period"

        get :search, {property_style: "contemporary"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## listed status
        get :search, {listed_status: "none"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["listed_status"], "None"

        get :search, {listed_status: "locally listed"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## decorative condition
        get :search, {decorative_condition: "excellent"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["decorative_condition"], "Excellent"

        get :search, {decorative_condition: "good"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## central heating
        get :search, {central_heating: "none"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["central_heating"], "None"

        get :search, {central_heating: "good"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## photos

        ## floorplan
        get :search, {floorplan: "no"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["floorplan"], "No"

        get :search, {floorplan: "yes"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## chain free
        get :search, {chain_free: "yes"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["chain_free"], "Yes"

        get :search, {chain_free: "no"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## council tax band
        get :search, {council_tax_band: "a"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["council_tax_band"], "A"

        get :search, {council_tax_band: "b"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## verification

        ## property_brochure

        ## new_homes

        ## retirement_homes

        ## shared_ownership

        ## memorandum_of_sale

        ## verification_status
        get :search, {verification_status: false}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["verification_status"], false

        get :search, {verification_status: true}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## agent_id
        get :search, {agent_id: 1}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["agent_id"], 1

        get :search, {agent_id: 2}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## district
        get :search, {district: SAMPLE_DISTRICT.downcase}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["district"], SAMPLE_DISTRICT

        get :search, {district: SAMPLE_DISTRICT.upcase}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## udprn
        get :search, {udprn: SAMPLE_UDPRN}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["udprn"], SAMPLE_UDPRN

        get :search, {udprn: SAMPLE_UDPRN + "1"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## vendor_id
        get :search, {vendor_id: 1}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["vendor_id"], 1

        get :search, {vendor_id: 2}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## postcode
        get :search, {postcode: SAMPLE_POSTCODE.split(' ').join('').downcase}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["postcode"], SAMPLE_POSTCODE.split(' ').join('')

        get :search, {postcode: SAMPLE_POSTCODE.upcase}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## sector
        ## Sector should be analyzed or non analyzed
        ## term not working but match working
        # get :search, {sector: SAMPLE_SECTOR}
        # assert_response 200
        # response = Oj.load(@response.body)
        # assert_equal response[0]["sector"], SAMPLE_SECTOR

        # get :search, {sector: SAMPLE_SECTOR.downcase}
        # assert_response 200
        # response = Oj.load(@response.body)
        # assert_equal response.length, 0

        ## unit
        get :search, {unit: "CH428NN".downcase}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["unit"], "CH428NN"

        get :search, {unit: "CH428NNN"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## building_name
        ## Sector should be analyzed or non analyzed
        ## term not working but match working
        # get :search, {building_name: SAMPLE_BUILDING_NAME.downcase}
        # assert_response 200
        # response = Oj.load(@response.body)
        # assert_equal response[0]["building_name"], SAMPLE_BUILDING_NAME

        # get :search, {building_name: SAMPLE_BUILDING_NAME.upcase}
        # assert_response 200
        # response = Oj.load(@response.body)
        # assert_equal response.length, 0

        ## building_number
        get :search, {building_number: SAMPLE_BUILDING_NUMBER}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["building_number"], SAMPLE_BUILDING_NUMBER

        get :search, {building_number: SAMPLE_BUILDING_NUMBER + "1"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## sub_building_name
        ## Sector should be analyzed or non analyzed
        ## term not working but match working
        # get :search, {sub_building_name: "Ember Society".downcase}
        # assert_response 200
        # response = Oj.load(@response.body)
        # assert_equal response[0]["sub_building_name"], "Ember Society"

        # get :search, {sub_building_name: "Ember Society".upcase}
        # assert_response 200
        # response = Oj.load(@response.body)
        # assert_equal response.length, 0

        ## post_code
        ## Sector should be analyzed or non analyzed
        ## term not working but match working
        # get :search, {post_code: SAMPLE_POSTCODE.downcase}
        # assert_response 200
        # response = Oj.load(@response.body)
        # assert_equal response[0]["post_code"], SAMPLE_POSTCODE

        # get :search, {post_code: SAMPLE_POSTCODE.upcase}
        # assert_response 200
        # response = Oj.load(@response.body)
        # assert_equal response.length, 0

        ## ads

        ## accepting_quotes
        get :search, {accepting_quotes: false}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["accepting_quotes"], false

        get :search, {accepting_quotes: true}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ################### Range Tests #####################

        ## Cost per month
        get :search, {min_cost_per_month: 4000}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["cost_per_month"], 4900

        get :search, {min_cost_per_month: 5000}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## Date added
        get :search, {min_date_added: "2016-06-30"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["date_added"], "2016-07-31"

        get :search, {min_date_added: "2016-08-01"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        # Floors
        get :search, {min_floors: 6}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["floors"], 6

        get :search, {min_floors: 7}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## Year built
        get :search, {min_year_built: "1961-01-01"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["year_built"], "1961-01-01"

        get :search, {min_year_built: "1961-01-02"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        # Internal property size
        get :search, {min_internal_property_size: 6788}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["internal_property_size"], 6789

        get :search, {min_internal_property_size: 6790}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## External property size
        get :search, {min_external_property_size: 6889}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["external_property_size"], 6889

        get :search, {min_external_property_size: 6890}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## total property size
        get :search, {min_total_property_size: 7000}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["total_property_size"], 7000

        get :search, {min_total_property_size: 7001}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## improvement spend
        get :search, {min_improvement_spend: 5555}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["improvement_spend"], 5557

        get :search, {min_improvement_spend: 6666}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## time frame
        get :search, {min_time_frame: "2012-01-01"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["time_frame"], "2012-01-01"

        get :search, {min_time_frame: "2013-01-02"}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## beds
        get :search, {min_beds: SAMPLE_BEDS}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["beds"], SAMPLE_BEDS

        get :search, {min_beds: SAMPLE_BEDS+1}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## baths
        get :search, {min_baths: SAMPLE_BATHS}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["baths"], SAMPLE_BATHS

        get :search, {min_baths: SAMPLE_BATHS+1}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## receptions
        get :search, {min_receptions: SAMPLE_RECEPTIONS}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["receptions"], SAMPLE_RECEPTIONS

        get :search, {min_receptions: SAMPLE_RECEPTIONS+1}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## current valuation
        get :search, {min_current_valuation: 553846}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["current_valuation"], 553846

        get :search, {min_current_valuation: 553847}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0

        ## dream price
        get :search, {min_dream_price: 720000}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response[0]["dream_price"], 720000

        get :search, {min_dream_price: 720001}
        assert_response 200
        response = Oj.load(@response.body)
        assert_equal response.length, 0
      end

      def teardown
        delete_es_address(SAMPLE_UDPRN)
      end

    end
  end
end