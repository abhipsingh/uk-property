### Base controller
class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def search_address
    regexes = [ /^([A-Z]{1,2})([0-9]{0,3})$/, /^([0-9]{1,2})([A-Z]{0,3})$/]
    if check_if_postcode?(params[:str].upcase, regexes)
      query_str = {filter: form_query(params[:str].upcase)}
      res, code = post_url('addresses', query_str, '_search')
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
      res, code = post_url('addresses', query_str, '_search')
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
        "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop.jpg",
        "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop2.jpg",
        "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop3.jpg",
      ]
    else
      result[:photo_urls] = []
    end

    result[:broker_logo] = "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop3.jpg"
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
      results, code= get_results_from_es_suggest(str)
      parsed_json = JSON.parse(results)
      res, code = find_results(parsed_json)
      res = JSON.parse(res)
      add_new_keys(res["hits"]["hits"][0]["_source"]) if res["hits"]["hits"].length > 0
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
    result, status = post_url('addresses', filters, '_search')
    result = JSON.parse(result)
    result = { result: result, hash_type: 'Text', hash_str: hashes.join("|") }
    return result, status
  end

  def get_results_from_es_suggest(query_str)
    query_str = {
      postcode_suggest: {
        text: query_str,
        completion: {
          field: 'suggest',
          size: 10
        }
      }
    }
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

  def post_url(index, query = {}, type='_suggest')
    uri = URI.parse(URI.encode("http://localhost:9200/#{index}/#{type}"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body,status
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
  def find_results(parsed_json)
    aggs = {}
    query = {}
    filters = {
      and: {
        filters: [
        ]
      }
    }
    first_type = parsed_json['postcode_suggest'][0]['options'][0]['payload']['type']
    hash_value = parsed_json['postcode_suggest'][0]['options'][0]['payload']['hash']
    county_value = parsed_json['postcode_suggest'][0]['options'][0]['payload']['county'].capitalize rescue nil
    post_code = parsed_json['postcode_suggest'][0]['options'][0]['payload']['post_code']
    if post_code.is_a?(Array)
      post_code = post_code.first
    end
    if first_type == 'county'
      insert_terms_aggs(aggs, 'area')
      inner_aggs = insert_terms_aggs(aggs, 'post_town')
      insert_term_filters(filters, 'county', hash_value)
    elsif first_type == 'post_town'
      insert_terms_aggs(aggs, 'district')
      inner_aggs = insert_terms_aggs({}, 'dependent_locality')
      aggs['district_aggs']['aggs'] = inner_aggs
      insert_term_filters(filters, first_type, hash_value)

      filtered_inner_aggs = {}
      insert_terms_aggs(filtered_inner_aggs, 'area')
      nested_aggs = {}
      insert_terms_aggs(nested_aggs, first_type)
      filtered_inner_aggs['area_aggs']['aggs'] = nested_aggs

      insert_global_aggs(aggs, 'post_town', append_filtered_aggs({}, 'post_town', 'county', county_value, filtered_inner_aggs))
    elsif first_type == 'dependent_locality' || first_type == 'double_dependent_locality'
      area = post_code.split(' ')[0].match(/([A-Z]{0,3})([0-9]{0,3})/)[1]
      insert_terms_aggs(aggs, 'sector')
      inner_aggs = insert_terms_aggs({}, 'dependent_thoroughfare_description')
      aggs['sector_aggs']['aggs'] = inner_aggs
      insert_term_filters(filters, 'hashes', hash_value)

      filtered_inner_aggs = {}
      insert_terms_aggs(filtered_inner_aggs, 'district')
      nested_aggs = {}
      insert_terms_aggs(nested_aggs, first_type)
      filtered_inner_aggs['district_aggs']['aggs'] = nested_aggs
      # p filtered_inner_aggs
      insert_global_aggs(aggs, first_type, append_filtered_aggs({}, first_type, 'area', area, filtered_inner_aggs))
    elsif ['thoroughfare_descriptor', 'dependent_thoroughfare_description'].include?(first_type)
      district = post_code.split(' ')[0]
      sector_unit = post_code.split(' ')[1]
      area = district.match(/([A-Z]{0,3})([0-9]{0,3})/)[1]
      sector = sector_unit.match(/([0-9]{0,3})([A-Z]{0,3})/)[1]
      append_filtered_aggs(aggs, 'district', 'area', area)
      append_filtered_aggs(aggs, 'dependent_locality', 'area', area)
      append_filtered_aggs(aggs, 'sector', 'district', district)
      append_filtered_aggs(aggs, 'unit', 'district', district)
      append_filtered_aggs(aggs, 'dependent_thoroughfare_description', 'district', district)
    end
    query[:size] = 1
    query[:aggs] = aggs
    query[:query] = { filtered: { filter: filters } }
    post_url('addresses', query, '_search')
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
      append_filtered_aggs(aggs, 'sector', 'district', district)
      append_filtered_aggs(aggs, 'dependent_thoroughfare_description', 'district', district)

    elsif [area, district, sector].all? { |e| !e.nil? && !e.empty? }
      district_1 = area + district
      sector = area + district + sector
      append_filtered_aggs(aggs, 'district', 'area', area)
      append_filtered_aggs(aggs, 'dependent_locality', 'area', area)
      append_filtered_aggs(aggs, 'unit', 'sector', sector)
      append_filtered_aggs(aggs, 'sector', 'district', district)
      append_filtered_aggs(aggs, 'dependent_thoroughfare_description', 'district', district)

    elsif [area, district].all? { |e|  !e.nil? && !e.empty? }
      district = area + district
      append_filtered_aggs(aggs, 'district', 'area', area)
      append_filtered_aggs(aggs, 'dependent_locality', 'area', area)
      append_filtered_aggs(aggs, 'sector', 'district', district)
      append_filtered_aggs(aggs, 'dependent_thoroughfare_description', 'district', district)

    elsif [area].all? { |e| !e.nil? && !e.empty? }
      insert_terms_aggs(aggs, 'district')
      insert_terms_aggs(aggs, 'dependent_locality')
      insert_terms_aggs(aggs, 'post_town')
      insert_term_filters(filters, 'area', area)

    end
    Rails.logger.info(aggs)
    query[:size] = 1
    query[:aggs] = aggs
    query[:query] = { filtered: { filter: filters } }
    post_url('addresses', query, '_search')
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

  def insert_term_filters(filters, term, value)
    filters[:and][:filters].push(append_term_filter(term, value))
  end

  def append_term_filter(term, value)
    { term: { term => value } }
  end
end
