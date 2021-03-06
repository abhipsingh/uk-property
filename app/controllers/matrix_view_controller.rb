class MatrixViewController < ActionController::Base
  include MatrixViewHelper

  LOCAL_EC2_URL = 'http://127.0.0.1:9200'
  ES_EC2_URL = Rails.configuration.remote_es_url
  ADDRESS_LEVELS = [:county, :post_town, :dependent_locality, :double_dependent_locality, :thoroughfare_description,
                    :dependent_thoroughfare_description, :sub_building_name, :building_name, :building_number]

  BUILDING_LEVELS = [:sub_building_name, :building_name, :building_number]

  def matrix_view_level
    response = nil
    attribute = params[:count_attr].to_s
    matrix_view_service = MatrixViewService.new(hash_str: params[:str])
    range_params = PropertySearchApi::FIELDS[:range].map{|t| ["min_#{t.to_s}", "max_#{t.to_s}"]}.flatten.map{|t| t.to_sym}
    #if false
    if (((PropertySearchApi::FIELDS[:terms] + PropertySearchApi::FIELDS[:term] + range_params) - PropertySearchApi::ADDRESS_LOCALITY_LEVELS - PropertySearchApi::POSTCODE_LEVELS) & params.keys.map(&:to_sym)).empty?
      cache_client = Rails.configuration.ardb_client
      response = cache_client.get("mvca_#{matrix_view_service.hash_str}")
      if response.nil?
        response = matrix_view_service.process_result_for_level(attribute)
        cache_client.set("mvca_#{matrix_view_service.hash_str}", response.to_json, {ex: 1.month})
      else
        response = Oj.load(response)
      end
    else
      values = POSTCODE_MATCH_MAP[matrix_view_service.level.to_s]
      values ||= ADDRESS_UNIT_MATCH_MAP[matrix_view_service.level.to_s]
      attrs = values.map{ |t| t[0] }
      response = {}
      if attrs.include?(attribute.to_s)
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
        response, code = find_results(hash, api.query[:filter], Rails.configuration.address_index_name, [values[attrs.index(attribute.to_s)]] )
      end
    end
    render json: response, status: 200
  end
  
  def matrix_view
    if params[:str] && params[:hash_type] != 'building_type'
      response = nil
      hash = { hash_str: params[:str] }
      PropertySearchApi.construct_hash_from_hash_str(hash)
      type_of_str(hash)
      range_params = PropertySearchApi::FIELDS[:range].map{|t| ["min_#{t.to_s}", "max_#{t.to_s}"]}.flatten.map{|t| t.to_sym}
      if (((PropertySearchApi::FIELDS[:terms] + PropertySearchApi::FIELDS[:term] + range_params) - PropertySearchApi::ADDRESS_LOCALITY_LEVELS - PropertySearchApi::POSTCODE_LEVELS) & params.keys.map(&:to_sym)).empty? && params[:sort_key].nil?
        cache_client = Rails.configuration.ardb_client
        matrix_view_service = MatrixViewService.new(hash_str: params[:str])
        response = cache_client.get("mvca_#{matrix_view_service.hash_str}")
        if response.nil?
          response = matrix_view_service.process_result
          cache_client.set("mvca_#{matrix_view_service.hash_str}", response.to_json, {ex: 1.month})
        else
          response = Oj.load(response)
        end
      else
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
        Rails.logger.info("QUERY_#{api.query}")
        area, district, sector, unit = compute_postcode_units(hash[type]) if hash[type]
        hash[:area] = area
        hash[:district] = district
        hash[:sector] = sector
        hash[:unit] = unit
        code = 200
        Rails.logger.info(hash[:type])
        response, code = find_results(hash, api.query[:filter]) 
      end
      if hash[:type] == :post_town
        dependent_localities = response['dependent_localities'] || response[:dependent_localities]
        dependent_localities ||= []
        dependent_localities.each do |dependent_locality|
          dl = dependent_locality[:dependent_locality] || dependent_locality['dependent_locality']
          pt = hash[:post_town]
          str = dl + ' ' + pt
          str = str.gsub(',',' ').strip.downcase
          str = str.gsub('.','')
          str = str.gsub('-','')
          results, code = PropertyService.get_results_from_es_suggest(str, 100)
          if code.to_i == 200
            udprn = Oj.load(results)['postcode_suggest'].first['options'].first['text'].split('_').first.to_i rescue nil
            if udprn
              basic_details = PropertyService.bulk_details([udprn]).first
              new_hash = MatrixViewService.form_hash(basic_details, :dependent_locality)
              dependent_locality[:hash_str] = new_hash
            end
          end
        end
      end
      render json: response, status: 200
    else
      render json: { message: 'Incorrect parameters value' }, status: 400
    end
  end

  def check_if_postcode_without_space?(str)
    str.match(/[A-Z]{0,3}[0-9]{0,3}[0-9]{0,3}[A-Z]{0,3}/).captures.any?{|t| !t.empty?}
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

  def find_results(hash, filter_hash, index_name=Rails.configuration.address_index_name, agg_fields=nil)
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
      construct_aggs_query_from_fields(area, district, sector, unit, 'county', first_type, query, filter_index, context_map, :address, agg_fields)
    elsif first_type == :post_town
      construct_aggs_query_from_fields(area, district, sector, unit, 'area', first_type, query, filter_index, context_map, :address, agg_fields)
    elsif first_type == :dependent_locality
      first_type = :dependent_locality
      construct_aggs_query_from_fields(area, district, sector, unit, 'district', first_type, query, filter_index, context_map, :address, agg_fields)
    elsif first_type == :dependent_thoroughfare_description || first_type == :thoroughfare_description
      ##first_type = 'dependent_thoroughfare_description'
      construct_aggs_query_from_fields(area, district, sector, unit, 'sector', first_type, query, filter_index, context_map, :address, agg_fields)
    elsif first_type == :building_type
      construct_aggs_query_from_fields(area, district, sector, unit, 'unit', first_type, query, filter_index, context_map, :address, agg_fields)
    end
    body, status = post_url(index_name, query, '_search', ES_EC2_URL)
    response = Oj.load(body).with_indifferent_access
    response_hash = construct_response_body_postcode(area, district, sector, unit, response, first_type, :address, context_map, hash, agg_fields)
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

end
