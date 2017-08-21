class MatrixViewController < ActionController::Base
  include MatrixViewHelper

  LOCAL_EC2_URL = 'http://127.0.0.1:9200'
  ES_EC2_URL = Rails.configuration.remote_es_url
  ADDRESS_LEVELS = [:county, :post_town, :dependent_locality, :double_dependent_locality, :thoroughfare_description,
                    :dependent_thoroughfare_description, :sub_building_name, :building_name, :building_number]

  BUILDING_LEVELS = [:sub_building_name, :building_name, :building_number]

  def predictive_search
    regexes = [[/^([A-Z]{1,2})([0-9]{0,3})$/, /^([A-Z]{1,2})([0-9]{1,3})([A-Z]{0,2})$/], /^([0-9]{1,2})([A-Z]{0,3})$/]
    str = nil
    if check_if_postcode?(params[:str].upcase, regexes)
      str = params[:str].upcase
    else
      str = params[:str].gsub(',',' ').downcase
    end
    results, code = get_results_from_es_suggest(str, 30)
    #Rails.logger.info(results)
    predictions = Oj.load(results)['postcode_suggest'][0]['options']
    #predictions.each { |t| t['score'] = t['score']*100 if t['payload']['hash'] == params[:str].upcase.strip }
    #predictions.each { |t| t['building_number'] = t['payload']['hash'].split('_')[*100 if t['payload']['hash'] == params[:str].upcase.strip }
    predictions.sort_by!{|t| (1.to_f/t['score'].to_f) }
    final_predictions = []
    #Rails.logger.info(predictions)
    udprns = []
    predictions = predictions.each do |t|
      text = t['text']
      if text.end_with?('bt') || text.end_with?('dl') || text.end_with?('td') || text.end_with?('dtd')
        udprns.push(text.split('_')[0].to_i)
      elsif text.start_with?('district') || text.start_with?('sector') || text.start_with?('unit')
        udprns.push(text.split('|')[1].to_i)
      end
    end
    Rails.logger.info(udprns)
    details = PropertyService.bulk_details(udprns)
    details = details.map{|t| t.with_indifferent_access }
    counter = 0
    predictions = predictions.each_with_index do |t, index|
      text = t['text']
      if text.end_with?('bt')
        address = PropertyDetails.address(details[counter])
        udprn = text.split('_')[0]
        hash = "@_@_@_@_@_@_@_@_#{udprn}"
        final_predictions.push({ hash: hash, output: address, type: 'building_type' })
        counter += 1
      elsif text.end_with?('dl') 
        output = "#{details[counter]['dependent_locality']} (#{details[counter]['post_town']}, #{details[counter]['district']})"
        hash = "@_#{details[counter]['post_town']}_#{details[counter]['dependent_locality']}_@_@_@_@_@_@|@_@_#{details[counter]['district']}"
        final_predictions.push({ hash: hash, output: output , type: 'dependent_locality'})
        counter += 1
      elsif  text.end_with?('dtd')
        loc = ''
        details[counter]['dependent_locality'].nil? ? loc = '' : loc = "#{details[counter]['dependent_locality']}, "
        output = "#{details[counter]['dependent_thoroughfare_description']} (#{loc}#{details[counter]['post_town']}, #{details[counter]['district']})"
        hash = "@_#{details[counter]['post_town']}_#{details[counter]['dependent_locality']}_@_#{details[counter]['dependent_thoroughfare_description']}_@_@_@_@|@_@_#{details[counter]['district']}"
        final_predictions.push({ hash: hash, output: output, type: 'dependent_thoroughfare_description' })
        counter += 1
      elsif text.end_with?('td')
        loc = ''
        details[counter]['dependent_locality'].nil? ? loc = '' : loc = "#{details[counter]['dependent_locality']}, "
        output = "#{details[counter]['thoroughfare_description']} (#{loc}#{details[counter]['post_town']}, #{details[counter]['district']})"
        hash = "@_#{details[counter]['post_town']}_#{details[counter]['dependent_locality']}_#{details[counter]['thoroughfare_description']}_@_@_@_@_@|@_@_#{details[counter]['district']}"
        final_predictions.push({ hash: hash, output: output, type: 'thoroughfare_description' })
        counter += 1
      elsif text.start_with?('district') 
        output = "#{details[counter]['district']}, #{details[counter]['post_town']}"
        hash = "@_#{details[counter]['post_town']}_@_@_@_@_@_@_@|@_@_#{details[counter]['district']}"
        final_predictions.push({ hash: hash, output: output, type: 'district' })
        counter += 1
      elsif text.start_with?('sector') 
        loc = ''
        dl = nil
        details[counter]['dependent_locality'].nil? ? loc = '' : loc = ", #{details[counter]['dependent_locality']}"
        output = "#{details[counter]['sector']}#{loc}"
        details[counter]['dependent_locality'].nil? ? dl = '@' : dl = details[counter]['dependent_locality']
        hash = "@_@_#{dl}_@_@_@_@_@_@|@_#{details[counter]['sector']}_@"
        final_predictions.push({ hash: hash, output: output, type: 'sector' })
        counter += 1
      elsif text.start_with?('unit')
        street = nil
        details[counter]['dependent_thoroughfare_description'].nil? ? street = details[counter]['thoroughfare_description'] : street = details[counter]['dependent_thoroughfare_description']
        output = "#{details[counter]['unit']}, #{street}"
        hash = "@_@_@_@_@_@_@_@_@|#{details[counter]['unit']}_@_@"
        final_predictions.push({ hash: hash, output: output, type: 'unit' })
        counter += 1
      elsif text.start_with?('post_town') || text.start_with?('county')
        output = text.split('|')[1].split('_').join(', ')
        hash_str = nil
        text.split('|')[0] == 'county' ? hash_str = "#{output}_@" : hash_str = "@_#{output.split(',')[0]}"
        hash = "#{hash_str}_@_@_@_@_@_@_@_@"
        final_predictions.push({ hash: hash, output: output, type: text.split('|')[0] })
      end
    end
    #Rails.logger.info(details)
    final_predictions = final_predictions.uniq{|t| t[:hash] }
    render json: final_predictions, status: code
  end

  def matrix_view
    regexes = [[/^([A-Z]{1,2})([0-9]{0,3})$/, /^([A-Z]{1,2})([0-9]{1,3})([A-Z]{0,2})$/], /^([0-9]{1,2})([A-Z]{0,3})$/]
    api = ::PropertySearchApi.new(filtered_params: params)
    api.modify_range_params
    if check_if_postcode?(params[:str].upcase.strip, regexes)
      str = params[:str].upcase
      results, code = get_results_from_es_suggest(str, 1)
      parsed_json = JSON.parse(results)
      api.apply_filters
      api.modify_query
      res, code = aggs_data_for_postcode(params[:str].upcase.strip, api.query, parsed_json)
    else
      str = params[:str].strip.gsub(',',' ').downcase
      results, code = get_results_from_es_suggest(str, 1)
      parsed_json = JSON.parse(results)
      #parsed_json = {"_shards"=>{"total"=>1, "successful"=>1, "failed"=>0}, "postcode_suggest"=>[{"text"=>"sunningdale", "offset"=>0, "length"=>11, "options"=>[{"text"=>"ascot sunningdale ", "score"=>100.0, "payload"=>{"hash"=>"ASCOT_Sunningdale", "hierarchy_str"=>"Sunningdale|Ascot|Berkshire", "post_code"=>"SL5 0AA", "type"=>"dependent_locality"}}, {"text"=>"leeds alwoodley sunningdale avenue ", "score"=>10.0, "payload"=>{"hash"=>"LEEDS_Alwoodley_Sunningdale Avenue", "hierarchy_str"=>"Sunningdale Avenue|Alwoodley|Leeds|West Yorkshire", "post_code"=>"LS17 7SD", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"york leeman road area sunningdale close ", "score"=>10.0, "payload"=>{"hash"=>"YORK_Leeman Road Area_Sunningdale Close", "hierarchy_str"=>"Sunningdale Close|Leeman Road Area|York|North Yorkshire", "post_code"=>"YO26 5PD", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"london bermondsey (part of) sunningdale close ", "score"=>10.0, "payload"=>{"hash"=>"LONDON_Bermondsey (Part Of)_Sunningdale Close", "hierarchy_str"=>"Sunningdale Close|Bermondsey (Part Of)|London|London", "post_code"=>"SE16 3BU", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"abergele llangernyw sunningdale ", "score"=>10.0, "payload"=>{"hash"=>"ABERGELE_Llangernyw_Sunningdale", "hierarchy_str"=>"Sunningdale|Llangernyw|Abergele|Clwyd", "post_code"=>"LL22 7UB", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"york nether poppleton sunningdale close ", "score"=>10.0, "payload"=>{"hash"=>"YORK_Nether Poppleton_Sunningdale Close", "hierarchy_str"=>"Sunningdale Close|Nether Poppleton|York|North Yorkshire", "post_code"=>"YO26 5PD", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"ascot sunningdale alpine close hancocks mount ", "score"=>10.0, "payload"=>{"hash"=>"ASCOT_Sunningdale_Alpine Close_Hancocks Mount", "hierarchy_str"=>"Hancocks Mount|Alpine Close|Sunningdale|Ascot|Berkshire", "post_code"=>"SL5 9WB", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"ascot sunningdale agincourt ", "score"=>10.0, "payload"=>{"hash"=>"ASCOT_Sunningdale_Agincourt", "hierarchy_str"=>"Agincourt|Sunningdale|Ascot|Berkshire", "post_code"=>"SL5 7SJ", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"manchester beswick sunningdale avenue ", "score"=>10.0, "payload"=>{"hash"=>"MANCHESTER_Beswick_Sunningdale Avenue", "hierarchy_str"=>"Sunningdale Avenue|Beswick|Manchester|Lancashire", "post_code"=>"M11 4HS", "type"=>"dependent_thoroughfare_description"}}, {"text"=>"leigh bedford sunningdale grove ", "score"=>10.0, "payload"=>{"hash"=>"LEIGH_Bedford_Sunningdale Grove", "hierarchy_str"=>"Sunningdale Grove|Bedford|Leigh|Lancashire", "post_code"=>"WN7 2XQ", "type"=>"dependent_thoroughfare_description"}}]}]}
      hash_value = top_suggest_result(parsed_json)
      ## Example of a hash value ASCOT_Sunningdale
      ### @filtered_params= {:str=>"Sunningdale", :controller=>"application", :action=>"matrix_view", :hash_str=>"ASCOT_Sunningdale", :hash_type=>"text"}
      ### @query = {size: 10000}
      ### {:size=>10000, :filter=>{:and=>{:filters=>[{:term=>{:match_type_str=>"ASCOT_Sunningdale|Normal", :_name=>:match_type_str}}], :or=>{:filters=>[]}}}}
      ### {:str=>"Sunningdale", :controller=>"application", :action=>"matrix_view", :hash_str=>"ASCOT_Sunningdale", :hash_type=>"text", :listing_type=>"Normal"}
      api.apply_filters
      api.modify_query
      ### Only query changes
      ### {:size=>20, :filter=>{:and=>{:filters=>[{:term=>{:match_type_str=>"ASCOT_Sunningdale|Normal", :_name=>:match_type_str}}, {:terms=>{"hashes"=>["ASCOT_Sunningdale"], :_name=>"hashes"}}], :or=>{:filters=>[]}}}, :from=>0}
      #Rails.logger.info(api.query)
      #Rails.logger.info(api.filtered_params)
      res, code = find_results(parsed_json, api.query[:filter]) 
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
    parts = str.split(" ")
    first_match = false
    first_match = regexes[0].any?{ |t| parts[0].match(t) } if parts[0]
    second_match = true
    second_match = !(parts[1].match(regexes[1])).nil? if parts[1]
    return first_match && second_match
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
    res, code = post_url(Rails.configuration.location_index_name, query_str)
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
    uri = URI.parse(URI.encode("#{host}/#{index}/#{type}")) if host != 'localhost'
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

  def top_suggest_result(parsed_json)
    parsed_json['postcode_suggest'][0]['options'][0]['payload']['hash'] rescue nil
  end

  def find_results(parsed_json, filter_hash)
    aggs = {}
    query = {}

    query[:query] = {
      filtered: {
        filter: filter_hash
      }
    }
    first_type, post_code, address_unit_val, hash = nil
    if parsed_json['postcode_suggest'][0]['options'].length > 0
      text = parsed_json['postcode_suggest'][0]['options'][0]['text']
      hash = get_address_and_type(text)
      first_type = hash[:type]
      post_code = hash[:postcode]
    end
    ### query = {:query=>{:filtered=>{:filter=>{:or=>{:filters=>[{:term=>{:match_type_str=>"ASCOT_Sunningdale|Normal", :_name=>:match_type_str}}, {:terms=>{"hashes"=>["ASCOT_Sunningdale"], :_name=>"hashes"}}]}}}}}
    ### dependent_locality__ASCOT_Sunningdale____SL5 0AA
    # Rails.logger.info("PARSED_JSON__#{parsed_json}")

    area, district, sector, unit = nil
    if post_code
      area = hash[:area]
      district = hash[:district]
      sector = hash[:sector]
      unit = hash[:unit]
    end

    context_map = hash
    context_map = context_map.with_indifferent_access
    filter_index = 0
    # Rails.logger.info("QUERY___#{query}")
    if first_type == 'county'
      construct_aggs_query_from_fields(area, district, sector, unit, 'county', first_type, query, filter_index, context_map, :address)
    elsif first_type == 'post_town'
      construct_aggs_query_from_fields(area, district, sector, unit, 'area', first_type, query, filter_index, context_map, :address)
    elsif first_type == 'dependent_locality' || first_type == 'double_dependent_locality'
      first_type = 'dependent_locality'
      construct_aggs_query_from_fields(area, district, sector, unit, 'district', first_type, query, filter_index, context_map, :address)
    elsif first_type == 'dependent_thoroughfare_description' || first_type == 'thoroughfare_description'
      ##first_type = 'dependent_thoroughfare_description'
      construct_aggs_query_from_fields(area, district, sector, unit, 'sector', first_type, query, filter_index, context_map, :address)
    elsif first_type == 'building_type'
      construct_aggs_query_from_fields(area, district, sector, unit, 'unit', first_type, query, filter_index, context_map, :address)
    end
    # Rails.logger.info(query)
    body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
    response = Oj.load(body).with_indifferent_access
    response_hash = construct_response_body_postcode(area, district, sector, unit, response, first_type, :address, context_map, hash)
    return response_hash, status
  end

  def aggs_data_for_postcode(post_code, filter_hash, parsed_json=nil)
    aggs = {}
    query = {}
    filter_hash[:filter] = [] if filter_hash[:filter].blank?
    response_hash = nil

    # Rails.logger.info(filter_hash)

    if filter_hash.is_a?(Hash) && filter_hash[:or] && filter_hash[:or][:filters]
      query[:query] = {
        filtered: {
          filter:  filter_hash 
        }
      }
    else
      if filter_hash.has_key?(:size) && filter_hash.has_key?(:filter) && filter_hash[:filter].is_a?(Hash) && filter_hash[:filter][:and] && filter_hash[:filter][:and][:filters]
        query[:query] = {
          filtered: {
            filter: {
              or: {
                filters: [{ and: { filters:  filter_hash[:filter][:and][:filters]}}]
              }
            }
          }
        }
      else
        query[:query] = {
          filtered: {
            filter: {
              or: {
                filters: []
              }
            }
          }
        }
      end
    end
    if query[:query][:filtered][:filter][:or] && query[:query][:filtered][:filter][:or][:filters].none?{ |t| t.keys.first.to_s == 'and'}
      query[:query][:filtered][:filter][:or][:filters].push({ and: { filters: [] }})
    end
    filter_index = query[:query][:filtered][:filter][:or][:filters].find_index { |t| t.keys.first.to_s == 'and' }
    hash = nil
    if parsed_json['postcode_suggest'][0]['options'].length > 0
      text = parsed_json['postcode_suggest'][0]['options'][0]['text']
      address_type = text.split('|')[0]
      hash[address_type] = post_code
      hash = get_address_and_type(text)
    end

    # Rails.logger.info("HASH_#{hash}__text#{text}")
    area = hash[:area]
    district = hash[:district]
    unit = hash[:unit]
    sector = hash[:sector]
    #Rails.logger.info("QUERY__#{query}")

    if hash[:type] == 'unit'
      construct_aggs_query_from_fields(area, district, sector, unit, 'district', 'unit', query, filter_index, hash)
      # Rails.logger.info(query)
      body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = construct_response_body_postcode(area, district, sector, unit, response, 'unit', :postcode, hash, hash)
    elsif hash[:type] == 'district'
      construct_aggs_query_from_fields(area, district, sector, unit, 'district', 'sector', query, filter_index, hash)
      body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = construct_response_body_postcode(area, district, sector, unit, response, 'sector', :postcode, hash, hash)
    elsif hash[:type] == 'sector'
      construct_aggs_query_from_fields(area, district, sector, unit,'area', 'district', query, filter_index, hash)
      body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = construct_response_body_postcode(area, district, sector, unit, response, 'district', :postcode, hash, hash)
    elsif hash[:type] == 'post_town'
      construct_aggs_query_from_fields(area, district, sector, unit,'area', 'area', query, filter_index, hash)
      body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = construct_response_body_postcode(area, district, sector, unit, response, 'area', :postcode, hash, hash)
    end
    return response_hash, status    
  end

  def compute_postcode_units(postcode)
    district_part, sector_part = postcode.split(' ')
    district_match = district_part.match(/([A-Z]{0,3})([0-9]{0,3})/)
    area = ''
    area = district_match[1] if district_part && !district_match[1].empty?
    district = ''
    district = district_match[1] + district_match[2] if district_part && !district_match[1].empty? && !district_match[2].empty?
    sector_match = sector_part.match(/([0-9]{0,3})([A-Z]{0,3})/) if sector_part
    sector_half = sector_match[1] if sector_part
    sector = ''
    sector = district + ' ' + sector_half.to_s if sector_half
    unit = ''
    unit = district_part + ' ' + sector_match[1] + sector_match[2] if sector_part && !sector_match[1].empty? && !sector_match[2].empty?
    return area, district, sector, unit
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

  def append_term_filter(term, value)
    { term: { term => value } }
  end

end
