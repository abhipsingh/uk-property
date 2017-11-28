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
    results, code = PropertyService.get_results_from_es_suggest(str, 100)
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
        output = "#{details[counter]['dependent_locality']} (#{details[counter]['post_town']}, #{details[counter]['county']}, #{details[counter]['district']})"
        hash = "@_#{details[counter]['post_town']}_#{details[counter]['dependent_locality']}_@_@_@_@_@_@|@_@_#{details[counter]['district']}"
        final_predictions.push({ hash: hash, output: output , type: 'dependent_locality'})
        counter += 1
      elsif  text.end_with?('dtd')
        loc = ''
        hash_loc = '@'
        hash_loc = details[counter]['dependent_locality'] if details[counter]['dependent_locality']
        details[counter]['dependent_locality'].nil? ? loc = '' : loc = "#{details[counter]['dependent_locality']}, "
        output = "#{details[counter]['dependent_thoroughfare_description']} (#{loc}#{details[counter]['post_town']}, #{details[counter]['county']}, #{details[counter]['district']})"
        hash = "@_#{details[counter]['post_town']}_#{hash_loc}_@_#{details[counter]['dependent_thoroughfare_description']}_@_@_@_@|@_@_#{details[counter]['district']}"
        final_predictions.push({ hash: hash, output: output, type: 'dependent_thoroughfare_description' })
        counter += 1
      elsif text.end_with?('td')
        loc = ''
        hash_loc = '@'
        hash_loc = details[counter]['dependent_locality'] if details[counter]['dependent_locality']
        details[counter]['dependent_locality'].nil? ? loc = '' : loc = "#{details[counter]['dependent_locality']}, "
        output = "#{details[counter]['thoroughfare_description']} (#{loc}#{details[counter]['post_town']}, #{details[counter]['county']}, #{details[counter]['district']})"
        hash = "@_#{details[counter]['post_town']}_#{hash_loc}_#{details[counter]['thoroughfare_description']}_@_@_@_@_@|@_@_#{details[counter]['district']}"
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
        text.split('|')[0] == 'county' ? hash_str = "#{output}_@" : hash_str = "#{output.split(',')[1].strip}_#{output.split(',')[0]}"
        hash = "#{hash_str}_@_@_@_@_@_@_@_@"
        final_predictions.push({ hash: hash, output: output, type: text.split('|')[0] })
      end
    end
    #Rails.logger.info(details)
    #final_predictions = final_predictions.uniq{|t| t[:hash] }
    render json: final_predictions, status: code
  end

#  def matrix_view
#    hash = { hash_str: params[:str] }
#    PropertySearchApi.construct_hash_from_hash_str(hash)
#    params.delete(:str)
#    hash.delete(:hash_str)
#    type_of_str(hash)
#    area, district, sector, unit = nil
#    if [:district, :sector, :unit].include?(hash[:type])
#      type = hash[:type]
#    else
#      type = PropertySearchApi::POSTCODE_LEVELS.reverse.select { |e| hash[e] }.first
#    end
#    new_params = params.merge!(hash)
#    new_params.delete(hash[:type])
#    api = ::PropertySearchApi.new(filtered_params: new_params)
#    api.modify_range_params
#    api.apply_filters
#    api.modify_query
#    area, district, sector, unit = compute_postcode_units(hash[type]) if hash[type]
#    hash[:area] = area
#    hash[:district] = district
#    hash[:sector] = sector
#    hash[:unit] = unit
#    code = 200
#    Rails.logger.info(hash[:type])
#    if [:district, :sector, :unit].include?(hash[:type])
#      res, code = aggs_data_for_postcode(hash, api.query)
#    else
#      res, code = find_results(hash, api.query[:filter]) 
#    end
#    render json: res, status: code
#  end
  
  def matrix_view
    response = nil
    range_params = PropertySearchApi::FIELDS[:range].map{|t| ["min_#{t.to_s}", "max_#{t.to_s}"]}.flatten.map{|t| t.to_sym}
    if (((PropertySearchApi::FIELDS[:terms] + PropertySearchApi::FIELDS[:term] + range_params) - PropertySearchApi::ADDRESS_LOCALITY_LEVELS - PropertySearchApi::POSTCODE_LEVELS) & params.keys.map(&:to_sym)).empty?
      matrix_view_service = MatrixViewService.new(hash_str: params[:str])
      response = matrix_view_service.process_result
    else
      hash = { hash_str: params[:str] }
      PropertySearchApi.construct_hash_from_hash_str(hash)
      params.delete(:str)
      hash.delete(:hash_str)
      type_of_str(hash)
      area, district, sector, unit = nil
      if [:district, :sector, :unit].include?(hash[:type])
        type = hash[:type]
      else
        type = PropertySearchApi::POSTCODE_LEVELS.reverse.select { |e| hash[e] }.first
      end
      new_params = params.merge!(hash)
      new_params.delete(hash[:type])
      api = ::PropertySearchApi.new(filtered_params: new_params)
      api.modify_range_params
      api.apply_filters
      api.modify_query
      area, district, sector, unit = compute_postcode_units(hash[type]) if hash[type]
      hash[:area] = area
      hash[:district] = district
      hash[:sector] = sector
      hash[:unit] = unit
      code = 200
      Rails.logger.info(hash[:type])
      response, code = find_results(hash, api.query[:filter]) 
    end
    render json: response, status: 200
  end

  def matrix_view_load_testing
    response = nil
    range_params = PropertySearchApi::FIELDS[:range].map{|t| ["min_#{t.to_s}", "max_#{t.to_s}"]}.flatten.map{|t| t.to_sym}
    if (((PropertySearchApi::FIELDS[:terms] + PropertySearchApi::FIELDS[:term] + range_params) - PropertySearchApi::ADDRESS_LOCALITY_LEVELS - PropertySearchApi::POSTCODE_LEVELS) & params.keys.map(&:to_sym)).empty?
      matrix_view_service = MatrixViewService.new(hash_str: params[:str])
      response = matrix_view_service.process_result
    else
      hash = { hash_str: params[:str] }
      PropertySearchApi.construct_hash_from_hash_str(hash) if hash[:hash_str]
      params.delete(:str)
      hash.delete(:hash_str)
      type_of_str(hash)
      area, district, sector, unit = nil
      if [:district, :sector, :unit].include?(hash[:type])
        type = hash[:type]
      else
        type = PropertySearchApi::POSTCODE_LEVELS.reverse.select { |e| hash[e] }.first
      end
      new_params = params.merge!(hash)
      new_params.delete(hash[:type])
      api = ::PropertySearchApi.new(filtered_params: new_params)
      api.modify_range_params
      api.apply_filters
      api.modify_query
      area, district, sector, unit = compute_postcode_units(hash[type]) if hash[type]
      hash[:area] = area
      hash[:district] = district
      hash[:sector] = sector
      hash[:unit] = unit
      code = 200
      Rails.logger.info(hash[:type])
      response, code = find_results(hash, api.query[:filter], 'addresses_load_testing') 
    end
    render json: response, status: 200
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

  def find_results(hash, filter_hash, index_name=Rails.configuration.address_index_name)
    aggs = {}
    query = {}

    query[:query] = {
      filtered: {
        filter: filter_hash
      }
    }
    first_type = hash[:type]
    ### query = {:query=>{:filtered=>{:filter=>{:or=>{:filters=>[{:term=>{:match_type_str=>"ASCOT_Sunningdale|Normal", :_name=>:match_type_str}}, {:terms=>{"hashes"=>["ASCOT_Sunningdale"], :_name=>"hashes"}}]}}}}}
    ### dependent_locality__ASCOT_Sunningdale____SL5 0AA
    # Rails.logger.info("PARSED_JSON__#{parsed_json}")

    area = hash[:area]
    district = hash[:district]
    sector = hash[:sector]
    unit = hash[:unit]

    context_map = hash
    context_map = context_map.with_indifferent_access
    filter_index = 0
    # Rails.logger.info("QUERY___#{query}__#{context_map}__#{first_type}")
    if first_type == :county
      construct_aggs_query_from_fields(area, district, sector, unit, 'county', first_type, query, filter_index, context_map, :address)
    elsif first_type == :post_town
      construct_aggs_query_from_fields(area, district, sector, unit, 'area', first_type, query, filter_index, context_map, :address)
    elsif first_type == :dependent_locality
      first_type = :dependent_locality
      construct_aggs_query_from_fields(area, district, sector, unit, 'district', first_type, query, filter_index, context_map, :address)
    elsif first_type == :dependent_thoroughfare_description || first_type == :thoroughfare_description
      ##first_type = 'dependent_thoroughfare_description'
      construct_aggs_query_from_fields(area, district, sector, unit, 'sector', first_type, query, filter_index, context_map, :address)
    elsif first_type == :building_type
      construct_aggs_query_from_fields(area, district, sector, unit, 'unit', first_type, query, filter_index, context_map, :address)
    end
    Rails.logger.info(query)
    body, status = post_url(index_name, query, '_search', ES_EC2_URL)
    response = Oj.load(body).with_indifferent_access
    response_hash = construct_response_body_postcode(area, district, sector, unit, response, first_type, :address, context_map, hash)
    return response_hash, status
  end

  def aggs_data_for_postcode(hash, filter_hash)
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

    # Rails.logger.info("HASH_#{hash}__text#{text}")
    area = hash[:area]
    district = hash[:district]
    unit = hash[:unit]
    sector = hash[:sector]
    #Rails.logger.info("QUERY__#{query}")

    if hash[:type] == :unit
      construct_aggs_query_from_fields(area, district, sector, unit, 'district', 'unit', query, filter_index, hash)
      # Rails.logger.info(query)
      body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = construct_response_body_postcode(area, district, sector, unit, response, 'unit', :postcode, hash, hash)
    elsif hash[:type] == :sector
      construct_aggs_query_from_fields(area, district, sector, unit, 'district', 'sector', query, filter_index, hash)
      body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = construct_response_body_postcode(area, district, sector, unit, response, 'sector', :postcode, hash, hash)
    elsif hash[:type] == :district
      construct_aggs_query_from_fields(area, district, sector, unit,'area', 'district', query, filter_index, hash)
      body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = construct_response_body_postcode(area, district, sector, unit, response, 'district', :postcode, hash, hash)
    elsif hash[:type] == :area
      construct_aggs_query_from_fields(area, district, sector, unit,'area', 'area', query, filter_index, hash)
      body, status = post_url(Rails.configuration.address_index_name, query, '_search', ES_EC2_URL)
      response = Oj.load(body).with_indifferent_access
      response_hash = construct_response_body_postcode(area, district, sector, unit, response, 'area', :postcode, hash, hash)
    end
    return response_hash, status
  end

  def compute_postcode_units(postcode)
    district_part, sector_part = postcode.split(' ')
    district_match = district_part.match(/([A-Z]{0,3})([0-9]{0,3}[A-Z]{0,2})/)
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
