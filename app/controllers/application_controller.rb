### Base controller
class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # before_action :authenticate_property_user!, except: [:follow]
  protect_from_forgery with: :exception

  skip_before_action :verify_authenticity_token

  LOCAL_EC2_URL = 'http://127.0.0.1:9200'
  ES_EC2_URL = Rails.configuration.remote_es_url

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || (root_path)
  end

  def search_address
    regexes = [ /^([A-Z]{1,2})([0-9]{0,3})$/, /^([0-9]{1,2})([A-Z]{0,3})$/]
    if check_if_postcode?(params[:str].upcase, regexes)
      query_str = {filter: form_query(params[:str].upcase)}
      res, code = post_url('addresses', query_str, '_search', ES_EC2_URL)
      res = JSON.parse(res)["hits"]["hits"].map{ |t| t["_source"] }
      res.map{ |t| add_new_keys(t) }
      res = { result: res, hash_str: params[:str], hash_type: 'postcode' }
      render json: res, status: code
    elsif !(params[:str].upcase).match(/([A-Z]{0,3})([0-9]{0,6})([A-Z]{0,3})/).captures.any?{|t| !t.empty?}
      matches =  (params[:str].upcase).match(/([A-Z]{0,3})([0-9]{0,6})([A-Z]{0,3})/)
      area = matches[1]
      unit = params[:str].upcase
      filter = {
        and: {
          filters: [
          ]
        }
      }
      new_filter = filter.deep_dup
      append_term_query(filter, 'area', area)
      append_term_query(filter, 'unit', unit)
      or_filter = {
        or: {
          filters: [
          ]
        }
      }
      district_sector_matches = matches[2]
      characters = district_sector_matches.split("")
      if district_sector_matches.length == 2
        district = area + district_sector_matches[0]
        sector = district + district_sector_matches[1]
        append_term_query(filter, 'district', district)
        append_term_query(filter, 'sector', sector)
      elsif district_sector_matches.length == 3
        district = area + district_sector_matches[0..1]
        sector = district + district_sector_matches[2]
        first_and_filter = new_filter.deep_dup
        append_term_query(first_and_filter, 'district', district)
        append_term_query(first_and_filter, 'sector', sector)
        first_or_filter = or_filter.deep_dup
        first_or_filter[:or][:filters].push(first_and_filter)

        district = area + district_sector_matches[0]
        sector = district + district_sector_matches[1..2]
        second_and_filter = new_filter.deep_dup
        append_term_query(second_and_filter, 'district', district)
        append_term_query(second_and_filter, 'sector', sector)
        first_or_filter[:or][:filters].push(second_and_filter)
        filter[:and][:filters].push(first_or_filter)
      end
      query_str = {filter: filter}
      res, code = post_url('addresses', query_str, '_search',ES_EC2_URL)
      res = JSON.parse(res)["hits"]["hits"].map{ |t| t["_source"] }
      res.map{ |t| add_new_keys(t) }
      render json: res, status: code
    else
      str = params[:str].gsub(',',' ').downcase
      results, code = get_results_from_es_suggest(str)
      results, code = get_results_for_search_term(results)
      results_new = results[:result]["hits"]["hits"].map{ |t| t["_source"] }
      results_new.map{ |t| add_new_keys(t) }
      results = { result: results_new, hash_type: results[:hash_type], hash_str: results[:hash_str] }
      render json: results, status: code
    end
  end

  def predictive_search
    str = params[:str].gsub(',',' ').downcase
    results, code = get_results_from_es_suggest(str, 50)
    Rails.logger.info(results)
    results = Oj.load(results)['postcode_suggest'].map { |e| e['options'].map{ |t| { hash: t['payload']['hash'], output: t['payload']['hierarchy_str'].split('|').join(', ') } } }.flatten
    render json: results, status: code
  end

  def get_results_from_hashes
    hash = params[:hash]
    filters = { 
      size: 100, 
      filter: {
        term: {
          hashes: hash
        }
      }
    }
    result, status = post_url('addresses', filters, '_search',ES_EC2_URL)
    result = JSON.parse(result)["hits"]["hits"].map { |e| e["_source"] }
    result = { result: result, hash_type: 'Text', hash_str: hash }
    render json: result, status: 200
  end 

  def add_new_keys(result)
    characters = (1..10).to_a
    alphabets = ('A'..'Z').to_a
    start_date = 3.months.ago
    ending_date = 4.hours.ago
    years = (1955..2015).step(10).to_a
    time_frame_years = (2004..2016).step(1).to_a
    days = (1..24).to_a
    ::PropertyDetailsRepo::RANDOM_SEED_MAP.each do |key, values|
      result[key] = values.sample(1).first
    end
    result[:date_added] = Time.at((start_date.to_f - ending_date.to_f)*rand + start_date.to_f).utc.strftime('%Y-%m-%d %H:%M:%S')
    result[:time_frame] = time_frame_years.sample(1).first.to_s + "-01-01"
    result[:external_property_size] = result[:internal_property_size] + 100
    result[:total_property_size] = result[:external_property_size] + 100
    result[:budget] = result[:price]

    if result[:photos] == "Yes"
      result[:photo_count] = 3
      result[:photo_urls] = [
        "#{LOCAL_EC2_URL}/prop.jpg",
        "#{LOCAL_EC2_URL}/prop2.jpg",
        "#{LOCAL_EC2_URL}/prop3.jpg",
      ]
    else
      result[:photo_urls] = []
    end
    result[:new_property_link] = "#{LOCAL_EC2_URL}/properties/new/#{result['udprn']}/short"
    result[:broker_logo] = "#{LOCAL_EC2_URL}/prop3.jpg"
    result[:broker_contact] = "020 3641 4259"
    description = ''
    result[:description] = characters.sample(1).first.times do
      description += alphabets.sample(1).first
    end
  end

  def matrix_view
    regexes = [ /^([A-Z]{1,2})([0-9]{0,3})$/, /^([0-9]{1,2})([A-Z]{0,3})$/]
    if check_if_postcode?(params[:str].upcase, regexes)
      res, code = aggs_data_for_postcode(params[:str].upcase)
    else
      str = params[:str].gsub(',',' ').downcase
      results, code = get_results_from_es_suggest(str)
      parsed_json = JSON.parse(results)
      #parsed_json = {"_shards"=>{"total"=>1, "successful"=>1, "failed"=>0}, "postcode_suggest"=>[{"text"=>"sunningdale", "offset"=>0, "length"=>11, "options"=>[{"text"=>"ascot sunningdale ", "score"=>100.0, "payload"=>{"hash"=>"ASCOT_Sunningdale", "hierarchy_str"=>"Sunningdale|Ascot|Berkshire", "post_code"=>"SL5 0AA", "type"=>"dependent_locality"}}, {"text"=>"leeds alwoodley sunningdale avenue ", "score"=>10.0, "payload"=>{"hash"=>"LEEDS_Alwoodley_Sunningdale Avenue", "hierarchy_str"=>"Sunningdale Avenue|Alwoodley|Leeds|West Yorkshire", "post_code"=>"LS17 7SD", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"york leeman road area sunningdale close ", "score"=>10.0, "payload"=>{"hash"=>"YORK_Leeman Road Area_Sunningdale Close", "hierarchy_str"=>"Sunningdale Close|Leeman Road Area|York|North Yorkshire", "post_code"=>"YO26 5PD", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"london bermondsey (part of) sunningdale close ", "score"=>10.0, "payload"=>{"hash"=>"LONDON_Bermondsey (Part Of)_Sunningdale Close", "hierarchy_str"=>"Sunningdale Close|Bermondsey (Part Of)|London|London", "post_code"=>"SE16 3BU", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"abergele llangernyw sunningdale ", "score"=>10.0, "payload"=>{"hash"=>"ABERGELE_Llangernyw_Sunningdale", "hierarchy_str"=>"Sunningdale|Llangernyw|Abergele|Clwyd", "post_code"=>"LL22 7UB", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"york nether poppleton sunningdale close ", "score"=>10.0, "payload"=>{"hash"=>"YORK_Nether Poppleton_Sunningdale Close", "hierarchy_str"=>"Sunningdale Close|Nether Poppleton|York|North Yorkshire", "post_code"=>"YO26 5PD", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"ascot sunningdale alpine close hancocks mount ", "score"=>10.0, "payload"=>{"hash"=>"ASCOT_Sunningdale_Alpine Close_Hancocks Mount", "hierarchy_str"=>"Hancocks Mount|Alpine Close|Sunningdale|Ascot|Berkshire", "post_code"=>"SL5 9WB", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"ascot sunningdale agincourt ", "score"=>10.0, "payload"=>{"hash"=>"ASCOT_Sunningdale_Agincourt", "hierarchy_str"=>"Agincourt|Sunningdale|Ascot|Berkshire", "post_code"=>"SL5 7SJ", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"manchester beswick sunningdale avenue ", "score"=>10.0, "payload"=>{"hash"=>"MANCHESTER_Beswick_Sunningdale Avenue", "hierarchy_str"=>"Sunningdale Avenue|Beswick|Manchester|Lancashire", "post_code"=>"M11 4HS", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"leigh bedford sunningdale grove ", "score"=>10.0, "payload"=>{"hash"=>"LEIGH_Bedford_Sunningdale Grove", "hierarchy_str"=>"Sunningdale Grove|Bedford|Leigh|Lancashire", "post_code"=>"WN7 2XQ", "type"=>"dependent_thoroughfare_description"}}]}]}
      hash_value = top_suggest_result(parsed_json)
      ## Example of a hash value ASCOT_Sunningdale
      params[:hash_str] = hash_value
      params[:hash_type] = 'text'
      api = ::PropertyDetailsRepo.new(filtered_params: params)
      api.modify_filtered_params
      ### @filtered_params= {:str=>"Sunningdale", :controller=>"application", :action=>"matrix_view", :hash_str=>"ASCOT_Sunningdale", :hash_type=>"text"}
      ### @query = {size: 10000}
      api.append_premium_or_featured_filter
      ### {:size=>10000, :filter=>{:and=>{:filters=>[{:term=>{:match_type_str=>"ASCOT_Sunningdale|Normal", :_name=>:match_type_str}}], :or=>{:filters=>[]}}}}
      ### {:str=>"Sunningdale", :controller=>"application", :action=>"matrix_view", :hash_str=>"ASCOT_Sunningdale", :hash_type=>"text", :listing_type=>"Normal"}
      api.apply_filters
      api.modify_query
      ### Only query changes
      ### {:size=>20, :filter=>{:and=>{:filters=>[{:term=>{:match_type_str=>"ASCOT_Sunningdale|Normal", :_name=>:match_type_str}}, {:terms=>{"hashes"=>["ASCOT_Sunningdale"], :_name=>"hashes"}}], :or=>{:filters=>[]}}}, :from=>0}
      res, code = nil
      if api.query[:filter] && api.query[:filter][:and] && api.query[:filter][:and][:filters]
        res, code = find_results(parsed_json, api.query[:filter][:and][:filters])
      elsif api.query[:filter] && api.query[:filter][:or] && api.query[:filter][:or][:filters]
        res, code = find_results(parsed_json, api.query[:filter])
      else
        res, code = find_results(parsed_json, [])
      end
      res = JSON.parse(res) if res.is_a?(String)
      # add_new_keys(res["hits"]["hits"][0]["_source"]) if res["hits"]["hits"].length > 0
    end
    render json: res, status: code
  end

  def check_if_postcode_without_space?(str)
    str.match(/[A-Z]{0,3}[0-9]{0,3}[0-9]{0,3}[A-Z]{0,3}/).captures.any?{|t| !t.empty?}
  end

  def search_postcode
    render json: count_stats(get_results_from_es("postcodes", params[:str], 'text'))
  end

  def check_if_postcode?(str, regexes)
    str.split(" ").each_with_index.all?{|i, ind| i.match(regexes[ind]) }
  end

  def get_results_for_search_term(res)
    filters = { size: 100, filter:
                {
      terms: {
        hashes: []
      }
    }
    }
    hashes = []
    parsed_json = JSON.parse(res)
    if parsed_json['postcode_suggest'][0]['options'].length > 0
      first_type = parsed_json['postcode_suggest'][0]['options'][0]['payload']['type']
      if first_type == 'county'
        hashes = parsed_json['postcode_suggest'][0]['options'][0]['payload']['post_code']
      elsif first_type == 'post_town'
        hashes = [ parsed_json['postcode_suggest'][0]['options'][0]['payload']['hash'] ]
      else
        parsed_json['postcode_suggest'].map { |t| t['options'].map { |e| hashes.push(e['payload']['hash']) } }
      end
    end

    hashes = hashes.uniq
    filters[:filter][:terms][:hashes] = hashes
    result, status = post_url('addresses', filters, '_search', ES_EC2_URL)
    result = JSON.parse(result)
    result = { result: result, hash_type: 'Text', hash_str: hashes.join("|") }
    return result, status
  end

  def get_results_from_es_suggest(query_str, size=10)
    query_str = {
      postcode_suggest: {
        text: query_str,
        completion: {
          field: 'suggest',
          size: size
        }
      }
    }
    Rails.logger.info(query_str)
    res, code = post_url('locations', query_str)
  end

  def get_results_from_es(index, query_str, field)
    query_str = {
      postcode_suggest: {
        text: query_str,
        completion: {
          field: 'suggest',
          size: 10
        }
      }
    }

    res, code = post_url(index, query_str)
    #Rails.logger.info("#{res}_#{code}")
    array_of_res = JSON.parse(res)['postcode_suggest'].map { |t| t['options'].map { |e| e[field]  } }.flatten
  end

  def post_url(index, query = {}, type='_suggest', host='localhost')
    uri = URI.parse(URI.encode("#{ES_EC2_URL}/#{index}/#{type}")) if host != 'localhost'
    uri = URI.parse(URI.encode("http://#{host}:9200/#{index}/#{type}")) if host == 'localhost'
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body, status
  end


  def count_stats(res)
    result = {
      areas: Hash.new { 0 },
      districts: Hash.new { 0 },
      sectors: Hash.new { 0 },
      units: 0,
      sectors_list: [],
      result_list: []
    }

    res.each do |t|
      area_sector, dist_unit = t.split(' ')
      area_matches = area_sector.match(/([A-Z]+)([0-9]+)/)
      dist_matches = dist_unit.match(/([0-9]+)([A-Z]+)/)
      result[:areas][area_matches[1]] = result[:areas][area_matches[1]] + 1
      result[:districts]["#{area_matches[1]}#{area_matches[2]}"] = result[:districts]["#{area_matches[1]}#{area_matches[2]}"] + 1
      result[:sectors]["#{area_matches[1]}#{area_matches[2]}#{dist_matches[1]}"] = result[:sectors]["#{area_matches[1]}#{area_matches[2]}#{dist_matches[1]}"] + 1
      result[:units] = result[:units] + 1
      result[:sectors_list] |= ["#{area_matches[1]}#{area_matches[2]}#{dist_matches[1]}"]
      result[:result_list].push([t])
    end
    result
  end


  def form_query(str)
    filter = {
      and: {
        filters: [
        ]
      }
    }
    area, sector, district, unit = search_flats_for_postcodes(str)
    append_term_query(filter, 'area', area)
    append_term_query(filter, 'district', district)
    append_term_query(filter, 'sector', sector)
    append_term_query(filter, 'unit', unit)
    return filter
  end

  def append_term_query(filters, term, value)
    if value
      filters[:and][:filters].push({
        term: {
          term => value
        }
      })
    end
    return filters
  end
  def append_or_term_query(filters, term, value)
    if value
      filters[:or][:filters].push({
        term: {
          term => value
        }
      })
    end
    return filters
  end

  def search_flats_for_postcodes(str)
    area_unit, sector_unit = str.split(' ')
    regexes = [ /^([A-Z]{1,2})([0-9]{0,3})$/, /^([0-9]{1,2})([A-Z]{0,3})$/]
    area = area_unit.match(regexes[0])[1]
    district = area_unit unless area_unit.match(regexes[0])[2].empty?
    sector, unit = nil
    if  sector_unit && sector_unit.match(regexes[1])
      sector = district + sector_unit.match(regexes[1])[1]
      unit = area_unit + sector_unit unless sector_unit.match(regexes[1])[2].empty?
    end
    return area, sector, district, unit
  end

  def top_suggest_result(parsed_json)
    parsed_json['postcode_suggest'][0]['options'][0]['payload']['hash'] rescue nil
  end

  def find_results(parsed_json, filter_hash)
    aggs = {}
    query = {}

    filters = {
      and: {
        filters: [
        ]
      }
    }

    if filter_hash.is_a?(Hash) && filter_hash[:or] && filter_hash[:or][:filters]
      query[:query] = {
        filtered: {
          filter: filter_hash
        }
      }
    else
      query[:query] = {
        filtered: {
          filter: {
            or: {
              filters: filter_hash
            }
          }
        }
      }
    end

    first_type = parsed_json['postcode_suggest'][0]['options'][0]['payload']['type']
    hash_value = parsed_json['postcode_suggest'][0]['options'][0]['payload']['hash']
    county_value = parsed_json['postcode_suggest'][0]['options'][0]['payload']['county'].capitalize rescue nil
    post_code = parsed_json['postcode_suggest'][0]['options'][0]['payload']['post_code']
    ### query = {:query=>{:filtered=>{:filter=>{:or=>{:filters=>[{:term=>{:match_type_str=>"ASCOT_Sunningdale|Normal", :_name=>:match_type_str}}, {:terms=>{"hashes"=>["ASCOT_Sunningdale"], :_name=>"hashes"}}]}}}}}
    ### dependent_locality__ASCOT_Sunningdale____SL5 0AA
    if post_code.is_a?(Array)
      post_code = post_code.first
    end
    if first_type == 'county'
      insert_terms_nested_aggs(aggs, 'county', 'area')
      inner_aggs = insert_terms_nested_aggs(aggs, 'post_town', 'area')
      insert_term_filters(filters, 'county', hash_value)
      query[:size] = 1
      query[:aggs] = aggs
      query[:query] = { filtered: { filter: filters } }
      body, status = post_url('addresses', query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = Hash.new { [] }
      response_hash[:type] = first_type
      response[:aggregations][:area_post_town_aggs][:buckets].each do |nested_value|
        nested_value[:post_town_aggs][:buckets].each do |value|
          response_hash[:post_towns] = response_hash[:post_towns].push({ post_town: value[:key].capitalize, flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
        end
      end
      response_hash[:areas] = []
      response[:aggregations][:area_county_aggs][:buckets].each do |nested_value|
        nested_value[:county_aggs][:buckets].each do |value|
          response_hash[:areas] = response_hash[:areas].push({ area: nested_value[:key], flat_count: nested_value[:doc_count], scoped_postcode: nested_value[:key] })
        end
      end

      if response[:hits][:hits].first
        response_hash[:counties] = [ {county: hash_value, flat_count: response[:hits][:total], scoped_postcode: response[:hits][:hits].first[:_source][:area]} ]
        response_hash[:units] = []
        response_hash[:dependent_thoroughfare_descriptions] = []
        response_hash[:sectors] = []
        response_hash[:dependent_localities] = []
        response_hash[:districts] = []
        response_hash[:county] = response[:hits][:hits].first[:_source][:county]
        response_hash[:post_town] = response[:hits][:hits].first[:_source][:post_town]
        response_hash[:unit] = response[:hits][:hits].first[:_source][:unit]
        response_hash[:district] = response[:hits][:hits].first[:_source][:district]
        response_hash[:dependent_locality] = response[:hits][:hits].first[:_source][:dependent_locality]
        response_hash[:dependent_thoroughfare_description] = response[:hits][:hits].first[:_source][:dependent_thoroughfare_description]
        response_hash[:sector] = response[:hits][:hits].first[:_source][:sector]
        response_hash[:area] = response[:hits][:hits].first[:_source][:area]
        body = response_hash
      end

    elsif first_type == 'post_town'
      append_nested_filtered_aggs(aggs, 'dependent_locality', 'county', county_value, 'district')
      append_nested_filtered_aggs(aggs, 'post_town', 'county', county_value, 'area')
      append_nested_filtered_aggs(aggs, 'district', 'county', county_value, 'area')
      insert_term_filters(filters, first_type, hash_value)
      query[:size] = 1
      query[:aggs] = aggs
      query[:filter] = filters
      body, status = post_url('addresses', query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = Hash.new { [] }
      response_hash[:type] = first_type
      response_hash[:post_towns] = []
      response_hash[:areas] = []
      response_hash[:dependent_localities] = []
      response_hash[:districts] = []
      begin
        response[:aggregations][:post_town_aggs][:area_post_town_aggs][:buckets].each do |nested_value|
          nested_value[:post_town_aggs][:buckets].each do |value|
            response_hash[:post_towns] = response_hash[:post_towns].push({ post_town: value[:key].capitalize, flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
          response_hash[:areas] = response_hash[:areas].push({ area: nested_value[:key], flat_count: nested_value[:doc_count], scoped_postcode: nested_value[:key] })
        end
        response[:aggregations][:district_aggs][:area_district_aggs][:buckets].each do |nested_value|
          nested_value[:district_aggs][:buckets].each do |value|
            response_hash[:districts] = response_hash[:districts].push({ district: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response[:aggregations][:dependent_locality_aggs][:district_dependent_locality_aggs][:buckets].each do |nested_value|
          nested_value[:dependent_locality_aggs][:buckets].each do |value|
            response_hash[:dependent_localities] = response_hash[:dependent_localities].push({ dependent_locality: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end

        response_hash[:counties] = [{county: response[:hits][:hits].first[:_source][:county], flat_count: response[:hits][:total], scoped_postcode: response[:hits][:hits].first[:_source][:area]}]
        response_hash[:units] = []
        response_hash[:dependent_thoroughfare_descriptions] = []
        response_hash[:sectors] = []
        response_hash[:county] = response[:hits][:hits].first[:_source][:county]
        response_hash[:post_town] = response[:hits][:hits].first[:_source][:post_town]
        response_hash[:unit] = response[:hits][:hits].first[:_source][:unit]
        response_hash[:district] = response[:hits][:hits].first[:_source][:district]
        response_hash[:dependent_locality] = response[:hits][:hits].first[:_source][:dependent_locality]
        response_hash[:dependent_thoroughfare_description] = response[:hits][:hits].first[:_source][:dependent_thoroughfare_description]
        response_hash[:sector] = response[:hits][:hits].first[:_source][:sector]
        response_hash[:area] = response[:hits][:hits].first[:_source][:area]
        body = response_hash
      rescue StandardError => e
        body = response_hash
      end
    elsif first_type == 'dependent_locality' || first_type == 'double_dependent_locality'
      area = post_code.split(' ')[0].match(/([A-Z]{0,3})([0-9]{0,3})/)[1]
      district = post_code.split(' ')[0]
      # insert_terms_aggs(aggs, 'sector')
      # inner_aggs = insert_terms_aggs({}, 'dependent_thoroughfare_description')
      # aggs['sector_aggs']['aggs'] = inner_aggs
      insert_term_filters(filters, 'hashes', hash_value)

      append_filtered_aggs(aggs, 'district', 'area', area)
      append_nested_filtered_aggs(aggs, 'dependent_locality', 'area', area, 'district')
      append_nested_filtered_aggs(aggs, 'unit', 'district', district, 'sector')
      append_nested_filtered_aggs(aggs, 'sector', 'area', area, 'district')
      append_filtered_aggs(aggs, 'post_town', 'area', area)
      append_filtered_aggs(aggs, 'area', 'area', area)
      append_filtered_aggs(aggs, 'county', 'area', area)
      append_nested_filtered_aggs(aggs, 'dependent_thoroughfare_description', 'district', district, 'sector')
      # p filtered_inner_aggs
      # insert_global_aggs(aggs, first_type, append_filtered_aggs({}, first_type, 'area', area, filtered_inner_aggs))
      query[:size] = 1
      query[:aggs] = aggs
      query[:filter] = filters
      body, status = post_url('addresses', query, '_search', ES_EC2_URL)
      Rails.logger.info("QUERY")
      Rails.logger.info(query)
      Rails.logger.info("BODY")
      Rails.logger.info(body)
      response = Oj.load(body).with_indifferent_access
      response_hash = Hash.new { [] }
      response_hash[:type] = first_type
      begin
        response[:aggregations][:dependent_thoroughfare_description_aggs]["sector_dependent_thoroughfare_description_aggs"][:buckets].each do |nested_value|
          nested_value[:dependent_thoroughfare_description_aggs][:buckets].each do |value|
            response_hash[:dependent_thoroughfare_descriptions] = response_hash[:dependent_thoroughfare_descriptions].push({ dependent_thoroughfare_description: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response[:aggregations][:dependent_locality_aggs]["district_dependent_locality_aggs"][:buckets].each do |nested_value|
          nested_value[:dependent_locality_aggs][:buckets].each do |value|
            response_hash[:dependent_localities] = response_hash[:dependent_localities].push({ dependent_locality: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response[:aggregations][:district_aggs][:district_aggs][:buckets].each do |value|
          response_hash[:districts] = response_hash[:districts].push({ district: value[:key], flat_count: value[:doc_count], scoped_postcode: area })
        end      
        response[:aggregations][:post_town_aggs][:post_town_aggs][:buckets].each do |value|
          response_hash[:post_towns] = response_hash[:post_towns].push({ post_town: value[:key].capitalize, flat_count: value[:doc_count], scoped_postcode: area })
        end
        response[:aggregations][:unit_aggs]["sector_unit_aggs"][:buckets].each do |nested_value|
          nested_value[:unit_aggs][:buckets].each do |value|
            response_hash[:units] = response_hash[:units].push({ unit: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response[:aggregations][:sector_aggs]["district_sector_aggs"][:buckets].each do |nested_value|
          nested_value[:sector_aggs][:buckets].each do |value|
            response_hash[:sectors] = response_hash[:sectors].push({ sector: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response[:aggregations][:area_aggs][:area_aggs][:buckets].each do |value|
          response_hash[:areas] = response_hash[:areas].push({ area: value[:key], flat_count: value[:doc_count], scoped_postcode: area })
        end
        response[:aggregations][:county_aggs][:county_aggs][:buckets].each do |value|
          response_hash[:counties] = response_hash[:counties].push({ county: value[:key], flat_count: value[:doc_count], scoped_postcode: area })
        end

        if response[:hits][:hits].first
          response_hash[:county] = response[:hits][:hits].first[:_source][:county]
          response_hash[:post_town] = response[:hits][:hits].first[:_source][:post_town]
          response_hash[:unit] = response[:hits][:hits].first[:_source][:unit]
          response_hash[:district] = response[:hits][:hits].first[:_source][:district]
          response_hash[:dependent_locality] = response[:hits][:hits].first[:_source][:dependent_locality]
          response_hash[:dependent_thoroughfare_description] = response[:hits][:hits].first[:_source][:dependent_thoroughfare_description]
          response_hash[:sector] = response[:hits][:hits].first[:_source][:sector]
          response_hash[:area] = response[:hits][:hits].first[:_source][:area]
          body = response_hash
        end
      rescue StandardError => e
        body = response_hash
      end
    elsif ['thoroughfare_descriptor', 'dependent_thoroughfare_description'].include?(first_type)
      district = post_code.split(' ')[0]
      sector_unit = post_code.split(' ')[1]
      insert_term_filters(filters, 'hashes', hash_value)
      area = district.match(/([A-Z]{0,3})([0-9]{0,3})/)[1]
      sector = sector_unit.match(/([0-9]{0,3})([A-Z]{0,3})/)[1]
      append_filtered_aggs(aggs, 'district', 'area', area)
      append_nested_filtered_aggs(aggs, 'dependent_locality', 'area', area, 'district')
      append_nested_filtered_aggs(aggs, 'unit', 'district', district, 'sector')
      append_nested_filtered_aggs(aggs, 'sector', 'area', area, 'district')
      append_filtered_aggs(aggs, 'post_town', 'area', area)
      append_filtered_aggs(aggs, 'area', 'area', area)
      append_filtered_aggs(aggs, 'county', 'area', area)
      append_nested_filtered_aggs(aggs, first_type, 'district', district, 'sector')
      query[:size] = 1
      query[:aggs] = aggs
      query[:filter] = filters
      body, status = post_url('addresses', query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = Hash.new { [] }
      response_hash[:type] = first_type
      response_hash[:dependent_thoroughfare_descriptions] = []
      Rails.logger.info("RESPONSE_#{response}")
      Rails.logger.info("QUERY_#{query}")
      # begin
        response[:aggregations]["#{first_type}_aggs"]["sector_#{first_type}_aggs"][:buckets].each do |nested_value|
          nested_value["#{first_type}_aggs"][:buckets].each do |value|
            response_hash["#{first_type}s"] = response_hash["#{first_type}s"].push({ first_type => value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response_hash[:dependent_localities] = []
        response[:aggregations][:dependent_locality_aggs]["district_dependent_locality_aggs"][:buckets].each do |nested_value|
          nested_value[:dependent_locality_aggs][:buckets].each do |value|
            response_hash[:dependent_localities] = response_hash[:dependent_localities].push({ dependent_locality: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response_hash[:districts] = []
        response[:aggregations][:district_aggs][:district_aggs][:buckets].each do |value|
          response_hash[:districts] = response_hash[:districts].push({ district: value[:key], flat_count: value[:doc_count], scoped_postcode: area })
        end      
        response_hash[:post_towns] = []
        response[:aggregations][:post_town_aggs][:post_town_aggs][:buckets].each do |value|
          response_hash[:post_towns] = response_hash[:post_towns].push({ post_town: value[:key].capitalize, flat_count: value[:doc_count], scoped_postcode: area })
        end
        response_hash[:units] = []
        response[:aggregations][:unit_aggs]["sector_unit_aggs"][:buckets].each do |nested_value|
          nested_value[:unit_aggs][:buckets].each do |value|
            response_hash[:units] = response_hash[:units].push({ unit: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response_hash[:sectors] = []
        response[:aggregations][:sector_aggs]["district_sector_aggs"][:buckets].each do |nested_value|
          nested_value[:sector_aggs][:buckets].each do |value|
            response_hash[:sectors] = response_hash[:sectors].push({ sector: value[:key], flat_count: value[:doc_count], scoped_postcode: nested_value[:key] })
          end
        end
        response_hash[:areas] = []
        response[:aggregations][:area_aggs][:area_aggs][:buckets].each do |value|
          response_hash[:areas] = response_hash[:areas].push({ area: value[:key], flat_count: value[:doc_count], scoped_postcode: value[:key] })
        end
        response_hash[:counties] = []
        response[:aggregations][:county_aggs][:county_aggs][:buckets].each do |value|
          response_hash[:counties] = response_hash[:counties].push({ county: value[:key], flat_count: value[:doc_count], scoped_postcode: area })
        end

        if response[:hits][:hits].first
          response_hash[first_type] = response[:hits][:hits].first[:_source][first_type]
          response_hash[:county] = response[:hits][:hits].first[:_source][:county]
          response_hash[:post_town] = response[:hits][:hits].first[:_source][:post_town]
          response_hash[:unit] = response[:hits][:hits].first[:_source][:unit]
          response_hash[:district] = response[:hits][:hits].first[:_source][:district]
          response_hash[:dependent_locality] = response[:hits][:hits].first[:_source][:dependent_locality]
          response_hash[:dependent_thoroughfare_description] = response[:hits][:hits].first[:_source][:dependent_thoroughfare_description]
          response_hash[:sector] = response[:hits][:hits].first[:_source][:sector]
          response_hash[:area] = response[:hits][:hits].first[:_source][:area]
        end
      # rescue StandardError => e
      # end
      body = response_hash
    end
    return body, status
  end

  def aggs_data_for_postcode(post_code)
    aggs = {}
    query = {}
    filters = {
      and: {
        filters: [
        ]
      }
    }
    area, district, sector, unit = nil
    area_unit, sector_unit = post_code.split(" ")
    area_combs = area_unit.match(/([A-Z]{0,3})([0-9]{0,3})/)
    sector_combs = sector_unit.match(/([0-9]{0,3})([A-Z]{0,3})/) if sector_unit
    area, district = area_combs[1], area_combs[2]
    sector, unit = sector_combs[1], sector_combs[2] if sector_unit

    if [area, district, sector, unit].all? { |t| !t.nil?  && !t.empty? }
      sector = area + district + sector
      district = area + district
      append_filtered_aggs(aggs, 'district', 'area', area)
      append_filtered_aggs(aggs, 'dependent_locality', 'area', area)
      append_filtered_aggs(aggs, 'unit', 'sector', sector)
      append_filtered_aggs(aggs, 'sector', 'area', area)
      append_filtered_aggs(aggs, 'post_town', 'area', area)
      append_filtered_aggs(aggs, 'county', 'area', area)
      append_filtered_aggs(aggs, 'area', 'area', area)
      append_filtered_aggs(aggs, 'dependent_thoroughfare_description', 'area', area)
      insert_term_filters(filters, 'unit', post_code.split(" ").join(""))
      query[:size] = 1
      query[:aggs] = aggs
      query[:filter] = filters
      body, status = post_url('addresses', query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = Hash.new { [] }
      response_hash[:type] = 'unit'
      begin
        response[:aggregations][:dependent_thoroughfare_description_aggs][:dependent_thoroughfare_description_aggs][:buckets].each do |value|
          response_hash[:dependent_thoroughfare_descriptions] = response_hash[:dependent_thoroughfare_descriptions].push({ dependent_thoroughfare_description: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:dependent_localities] = []
        response[:aggregations][:dependent_locality_aggs][:dependent_locality_aggs][:buckets].each do |value|
          response_hash[:dependent_localities] = response_hash[:dependent_localities].push({ dependent_locality: value[:key], flat_count: value[:doc_count] })
        end
        response[:aggregations][:district_aggs][:district_aggs][:buckets].each do |value|
          response_hash[:districts] = response_hash[:districts].push({ district: value[:key], flat_count: value[:doc_count] })
        end      
        response[:aggregations][:post_town_aggs][:post_town_aggs][:buckets].each do |value|
          response_hash[:post_towns] = response_hash[:post_towns].push({ post_town: value[:key].capitalize, flat_count: value[:doc_count] })
        end
        response[:aggregations][:unit_aggs][:unit_aggs][:buckets].each do |value|
          response_hash[:units] = response_hash[:units].push({ unit: value[:key], flat_count: value[:doc_count] })
        end
        response[:aggregations][:sector_aggs][:sector_aggs][:buckets].each do |value|
          response_hash[:sectors] = response_hash[:sectors].push({ sector: value[:key], flat_count: value[:doc_count] })
        end
        response[:aggregations][:county_aggs][:county_aggs][:buckets].each do |value|
          response_hash[:counties] = response_hash[:counties].push({ county: value[:key], flat_count: value[:doc_count] })
        end
        response[:aggregations][:area_aggs][:area_aggs][:buckets].each do |value|
          response_hash[:areas] = response_hash[:areas].push({ area: value[:key], flat_count: value[:doc_count] })
        end
      rescue StandardError => e
      end
      body = response_hash
      response_hash[:county] = response[:hits][:hits].first[:_source][:county]
      response_hash[:post_town] = response[:hits][:hits].first[:_source][:post_town]
      response_hash[:unit] = response[:hits][:hits].first[:_source][:unit]
      response_hash[:district] = response[:hits][:hits].first[:_source][:district]
      response_hash[:dependent_locality] = response[:hits][:hits].first[:_source][:dependent_locality]
      response_hash[:dependent_thoroughfare_description] = response[:hits][:hits].first[:_source][:dependent_thoroughfare_description]
      response_hash[:sector] = response[:hits][:hits].first[:_source][:sector]
      response_hash[:area] = response[:hits][:hits].first[:_source][:area]

    elsif [area, district, sector].all? { |e| !e.nil? && !e.empty? }
      district_1 = area + district
      sector = area + district + sector
      append_filtered_aggs(aggs, 'district', 'area', area)
      append_filtered_aggs(aggs, 'dependent_locality', 'area', area)
      append_filtered_aggs(aggs, 'unit', 'district', post_code.split(' ')[0])
      append_filtered_aggs(aggs, 'sector', 'area', area)
      append_filtered_aggs(aggs, 'post_town', 'area', area)
      append_filtered_aggs(aggs, 'county', 'area', area)
      append_filtered_aggs(aggs, 'area', 'area', area)
      insert_term_filters(filters, 'sector', sector)
      append_filtered_aggs(aggs, 'dependent_thoroughfare_description', 'area', area)
      query[:size] = 1
      query[:aggs] = aggs
      query[:filter] = filters
      body, status = post_url('addresses', query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = Hash.new { [] }
      response_hash[:type] = 'sector'
      response_hash[:dependent_thoroughfare_descriptions] = []
      begin
        response[:aggregations][:dependent_thoroughfare_description_aggs][:dependent_thoroughfare_description_aggs][:buckets].each do |value|
          response_hash[:dependent_thoroughfare_descriptions] = response_hash[:dependent_thoroughfare_descriptions].push({ dependent_thoroughfare_description: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:dependent_localities] = []
        response[:aggregations][:dependent_locality_aggs][:dependent_locality_aggs][:buckets].each do |value|
          response_hash[:dependent_localities] = response_hash[:dependent_localities].push({ dependent_locality: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:districts] = []
        response[:aggregations][:district_aggs][:district_aggs][:buckets].each do |value|
          response_hash[:districts] = response_hash[:districts].push({ district: value[:key], flat_count: value[:doc_count] })
        end      
        response_hash[:post_towns] = []
        response[:aggregations][:post_town_aggs][:post_town_aggs][:buckets].each do |value|
          response_hash[:post_towns] = response_hash[:post_towns].push({ post_town: value[:key].capitalize, flat_count: value[:doc_count] })
        end
        response_hash[:units] = []
        response[:aggregations][:unit_aggs][:unit_aggs][:buckets].each do |value|
          response_hash[:units] = response_hash[:units].push({ unit: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:sectors] = []
        response[:aggregations][:sector_aggs][:sector_aggs][:buckets].each do |value|
          response_hash[:sectors] = response_hash[:sectors].push({ sector: value[:key], flat_count: value[:doc_count] })
        end
        response[:aggregations][:county_aggs][:county_aggs][:buckets].each do |value|
          response_hash[:counties] = response_hash[:counties].push({ county: value[:key], flat_count: value[:doc_count] })
        end
        response[:aggregations][:area_aggs][:area_aggs][:buckets].each do |value|
          response_hash[:areas] = response_hash[:areas].push({ area: value[:key], flat_count: value[:doc_count] })
        end
      rescue StandardError => e
      end
      body = response_hash
      response_hash[:county] = response[:hits][:hits].first[:_source][:county]
      response_hash[:post_town] = response[:hits][:hits].first[:_source][:post_town]
      response_hash[:unit] = response[:hits][:hits].first[:_source][:unit]
      response_hash[:district] = response[:hits][:hits].first[:_source][:district]
      response_hash[:dependent_locality] = response[:hits][:hits].first[:_source][:dependent_locality]
      response_hash[:dependent_thoroughfare_description] = response[:hits][:hits].first[:_source][:dependent_thoroughfare_description]
      response_hash[:sector] = response[:hits][:hits].first[:_source][:sector]
      response_hash[:area] = response[:hits][:hits].first[:_source][:area]
    elsif [area, district].all? { |e|  !e.nil? && !e.empty? }
      district = area + district
      append_filtered_aggs(aggs, 'district', 'area', area)
      append_filtered_aggs(aggs, 'dependent_locality', 'area', area)
      append_filtered_aggs(aggs, 'unit', 'district', district)
      append_filtered_aggs(aggs, 'sector', 'district', district)
      append_filtered_aggs(aggs, 'post_town', 'area', area)
      append_filtered_aggs(aggs, 'county', 'area', area)
      append_filtered_aggs(aggs, 'area', 'area', area)
      insert_term_filters(filters, 'district', district)
      append_filtered_aggs(aggs, 'dependent_thoroughfare_description', 'area', area)
      query[:size] = 1
      query[:aggs] = aggs
      query[:filter] = filters
      body, status = post_url('addresses', query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = Hash.new { [] }
      response_hash[:type] = 'district'
      response_hash[:dependent_thoroughfare_descriptions] = []
      begin
        response[:aggregations][:dependent_thoroughfare_description_aggs][:dependent_thoroughfare_description_aggs][:buckets].each do |value|
          response_hash[:dependent_thoroughfare_descriptions] = response_hash[:dependent_thoroughfare_descriptions].push({ dependent_thoroughfare_description: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:dependent_localities] = []
        response[:aggregations][:dependent_locality_aggs][:dependent_locality_aggs][:buckets].each do |value|
          response_hash[:dependent_localities] = response_hash[:dependent_localities].push({ dependent_locality: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:districts] = []
        response[:aggregations][:district_aggs][:district_aggs][:buckets].each do |value|
          response_hash[:districts] = response_hash[:districts].push({ district: value[:key], flat_count: value[:doc_count] })
        end      
        response_hash[:post_towns] = []
        response[:aggregations][:post_town_aggs][:post_town_aggs][:buckets].each do |value|
          response_hash[:post_towns] = response_hash[:post_towns].push({ post_town: value[:key].capitalize, flat_count: value[:doc_count] })
        end
        response_hash[:units] = []
        response[:aggregations][:unit_aggs][:unit_aggs][:buckets].each do |value|
          response_hash[:units] = response_hash[:units].push({ unit: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:sectors] = []
        response[:aggregations][:sector_aggs][:sector_aggs][:buckets].each do |value|
          response_hash[:sectors] = response_hash[:sectors].push({ sector: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:counties] = []
        response[:aggregations][:county_aggs][:county_aggs][:buckets].each do |value|
          response_hash[:counties] = response_hash[:counties].push({ county: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:areas] = []
        response[:aggregations][:area_aggs][:area_aggs][:buckets].each do |value|
          response_hash[:areas] = response_hash[:areas].push({ area: value[:key], flat_count: value[:doc_count] })
        end
      rescue StandardError => e
      end
      body = response_hash
      response_hash[:county] = response[:hits][:hits].first[:_source][:county]
      response_hash[:post_town] = response[:hits][:hits].first[:_source][:post_town]
      response_hash[:unit] = response[:hits][:hits].first[:_source][:unit]
      response_hash[:district] = response[:hits][:hits].first[:_source][:district]
      response_hash[:dependent_locality] = response[:hits][:hits].first[:_source][:dependent_locality]
      response_hash[:dependent_thoroughfare_description] = response[:hits][:hits].first[:_source][:dependent_thoroughfare_description]
      response_hash[:sector] = response[:hits][:hits].first[:_source][:sector]
      response_hash[:area] = response[:hits][:hits].first[:_source][:area]

    elsif [area].all? { |e| !e.nil? && !e.empty? }
      append_filtered_aggs(aggs, 'district', 'area', area)
      append_filtered_aggs(aggs, 'dependent_locality', 'area', area)
      append_filtered_aggs(aggs, 'post_town', 'area', area)
      insert_term_filters(filters, 'area', area)
      append_filtered_aggs(aggs, 'county', 'area', area)
      append_filtered_aggs(aggs, 'area', 'area', area)
      query[:size] = 1
      query[:aggs] = aggs
      query[:filter] = filters
      body, status = post_url('addresses', query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = Hash.new { [] }
      response_hash[:type] = 'area'
      response_hash[:dependent_thoroughfare_descriptions] = []
      response_hash[:units] = []
      response_hash[:sectors] = []
      begin
        response[:aggregations][:district_aggs][:district_aggs][:buckets].each do |value|
          response_hash[:districts] = response_hash[:districts].push({ district: value[:key], flat_count: value[:doc_count] })
        end      
        response[:aggregations][:post_town_aggs][:post_town_aggs][:buckets].each do |value|
          response_hash[:post_towns] = response_hash[:post_towns].push({ post_town: value[:key].capitalize, flat_count: value[:doc_count] })
        end
        response[:aggregations][:county_aggs][:county_aggs][:buckets].each do |value|
          response_hash[:counties] = response_hash[:counties].push({ county: value[:key], flat_count: value[:doc_count] })
        end
        response_hash[:dependent_localities] = []
        response[:aggregations][:dependent_locality_aggs][:dependent_locality_aggs][:buckets].each do |value|
          response_hash[:dependent_localities] = response_hash[:dependent_localities].push({ dependent_locality: value[:key], flat_count: value[:doc_count] })
        end
        response[:aggregations][:area_aggs][:area_aggs][:buckets].each do |value|
          response_hash[:areas] = response_hash[:areas].push({ area: value[:key], flat_count: value[:doc_count] })
        end
      rescue StandardError => e
      end
      body = response_hash
      response_hash[:county] = response[:hits][:hits].first[:_source][:county]
      response_hash[:post_town] = response[:hits][:hits].first[:_source][:post_town]
      response_hash[:unit] = response[:hits][:hits].first[:_source][:unit]
      response_hash[:district] = response[:hits][:hits].first[:_source][:district]
      response_hash[:dependent_locality] = response[:hits][:hits].first[:_source][:dependent_locality]
      response_hash[:dependent_thoroughfare_description] = response[:hits][:hits].first[:_source][:dependent_thoroughfare_description]
      response_hash[:sector] = response[:hits][:hits].first[:_source][:sector]
      response_hash[:area] = response[:hits][:hits].first[:_source][:area]
    end
    return body, status    
  end

  def insert_terms_aggs(aggs, term)
    aggs["#{term}_aggs"] = {
      terms: {
        field: term,
        size: 0
      }
    }
    aggs
  end

  def insert_terms_nested_aggs(aggs, term, nested_term)
    aggs["#{nested_term}_#{term}_aggs"] = {
      terms: {
        field: nested_term,
        size: 0
      },
      aggs: {
        "#{term}_aggs" => {
          terms: {
            field: term,
            size: 0
          }
        }
      }
    }
    aggs
  end

  def insert_global_aggs(aggs, term, inner_aggs)
    aggs["global_#{term}_aggs"] = {
      global: {},
      aggs: inner_aggs
    }
  end

  def append_filtered_aggs(aggs, term, filter_term, filter_value, optional_aggs={})
    aggs["#{term}_aggs"] = { filter: append_term_filter(filter_term, filter_value) }
    aggs["#{term}_aggs"]["aggs"] = {}
    if optional_aggs.empty?
      aggs["#{term}_aggs"]["aggs"]["#{term}_aggs"] = insert_terms_aggs({}, term)["#{term}_aggs"]
    else
      aggs["#{term}_aggs"]["aggs"].merge!(optional_aggs)
    end
    aggs
  end

  def append_nested_filtered_aggs(aggs, term, filter_term, filter_value, nested_term, optional_aggs={})
    aggs["#{term}_aggs"] = { filter: append_term_filter(filter_term, filter_value) }
    aggs["#{term}_aggs"]["aggs"] = {}
    if optional_aggs.empty?
      aggs["#{term}_aggs"]["aggs"]["#{nested_term}_#{term}_aggs"] = insert_terms_nested_aggs({}, term, nested_term)["#{nested_term}_#{term}_aggs"]
    else
      aggs["#{term}_aggs"]["aggs"].merge!(optional_aggs)
    end
    aggs
  end

  def insert_term_filters(filters, term, value)
    filters[:and][:filters].push(append_term_filter(term, value))
  end

  def append_term_filter(term, value)
    { term: { term => value } }
  end

  def follow
    location_type = params[:entity_type]
    location_text = params[:entity_id]
    ## Process afterwards
    render json: "Location #{location_text} followed", status: 200
  end
end
