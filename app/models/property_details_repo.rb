require 'base64'
require 'elasticsearch/persistence'
class PropertyDetailsRepo
  include Elasticsearch::Persistence::Repository
  include Elasticsearch::Search
  include Elasticsearch::Scripts
  NEARBY_DEFAULT_RADIUS = 1500
  NEARBY_MAX_RADIUS = 5000
  RESULTS_PER_PAGE = 20
  MAX_RESULTS_PER_PAGE = 150
  FIELDS = {
    terms: [:property_types, :monitoring_types, :property_status_types, :parking_types, :outside_space_types, :additional_feature_types, :keyword_types],
    term:  [:tenure, :epc, :property_style, :listed_status, :decorative_condition, :central_heating, :photos, :floorplan, :chain_free, :listing_type, :council_tax_band, :verification, :property_style, :property_brochure, :new_homes, :retirement_homes, :shared_ownership, :under_off],
    range: [:budget, :cost_per_month, :date_added, :floors, :year_built, :internal_property_size, :external_property_size, :total_property_size, :improvement_spend, :time_frame, :dream_price],
  }

  RANDOM_SEED_MAP = {
    property_type: ["Barn conversion","Bungalow","Cottage","Country house","Detached house","Detached bungalow","End terrace house","Equestrian property","Farm","Barn conversion/farmhouse","Farmhouse","Flat","Houseboat","Link-detached house","Lodge","Maisonnette","Mews house","Mobile/park home","Semi-detached house","Semi-detached bungalow","Studio","Terraced house","Terraced bungalow","Town house"],
    property_status_type: ["Green", "Amber", "Red"],
    monitoring_type: ["Yes", 'No'],
    beds: (1..10).to_a,
    baths: (1..10).to_a,
    receptions: (1..10).to_a,
    chain_free: ["Yes", "No"],
    tenure: ["Freehold","Share of freehold","Leasehold"],
    epc: ["Yes", "No"],
    cost_per_month: (1000..5000).step(100).to_a,
    budget: (100000..1000000).step(10000).to_a,
    price: (100000..1000000).step(10000).to_a,
    property_style: ["Period","New build","Contemporary","Purpose built","Thatched","Mansion block","Low build","Council","Park home","Don’t know","Barn conversion","Church conversion","Other conversion"],
    floors: (1..6).to_a,
    listed_status: ["None","Grade I","Grade II","Grade II*","Locally listed"],
    decorative_condition: ["Newly refurbished","Excellent","Good","Average","Needs modernisation"],
    central_heating: ["None","Partial","Throughout"],
    parking_type: ["Single garage","Double garage","Underground","Off street","On street/residents","None"],
    outside_space_type: ["Private garden","Communal garden","Roof terrace","Terrace","Balcony","None"],
    additional_features_type: ["Attractive views","Ensuite bathroom","Loft/attic","Rural/secluded","Basement/cellar","Fireplace","Outbuildings/stables","Swimming pool","Bespoke fixtures","Gated","Penthouse","Tennis court","Conservatory","Gym/sauna","Period features","Waterfront","Double glazing","Laundry/utility room","Porter/security","Wood floors"],
    internal_property_size: (1000..10000).to_a,
    improvement_spend: (1000..10000).to_a,
    year_built: (1955..2015).to_a,
    photos: ["Yes", "No"],
    listing_type: ["Basic", "Premium", "Featured"],
    floorplan: ["Yes", "No"]
  }

  def initialize(options={})
    index  options[:index] || 'property_details'
    client Elasticsearch::Client.new url: options[:url], log: options[:log]
    @filtered_params = options[:filtered_params].symbolize_keys
    @query = self.class.append_empty_hash
    @query = options[:query] if @is_query_custom == true
  end

  def filter
    inst = self
    inst = inst.append_hash_filter
    inst = inst.append_pagination_filter
    inst = inst.append_terms_filters
    inst = inst.append_term_filters
    inst = inst.append_range_filters
    inst = inst.append_sort_filters
    Rails.logger.info(inst.query)
    body, status = post_url(inst.query, 'addresses', 'address')
    body = JSON.parse(body)['hits']['hits'].map { |t| t['_source']['score'] = t['matched_queries'].count ;t['_source']; }
    return { results: body }, status
  end

  def append_hash_filter
    inst = self
    if filtered_params[:hash_type] == 'postcode'
      inst = form_query(filtered_params[:hash_str])
    else
      inst = inst.append_terms_filter_query('hashes', filtered_params[:hash_str].split('|'), :and)
    end
    return inst
  end

  def append_term_filters
    inst = self
    term_filters = @filtered_params.keys & FIELDS[:term]
    term_filters.each{|t| inst = inst.append_term_filter_query(t,@filtered_params[t], :and)}
    inst
  end

  def append_range_filters
    inst = self
    FIELDS[:range].each do |each_field|
      min_value = @filtered_params.select{|t| t.to_s.ends_with?(each_field.to_s) && t.to_s.starts_with?("min")}
      max_value = @filtered_params.select{|t| t.to_s.ends_with?(each_field.to_s) && t.to_s.starts_with?("max")}
      unless max_value.empty? && min_value.empty?
        inst = inst.append_range_filter_query(each_field,min_value.values.first,max_value.values.first)
      end
    end
    inst
  end

  def append_terms_filters
    inst = self
    terms_filters = @filtered_params.keys & FIELDS[:terms]
    terms_filters.each{|t|  inst = inst.append_terms_filter_query(t.to_s.singularize, @filtered_params[t].split(","), :and)}
    inst
  end

  def append_pagination_filter(size = RESULTS_PER_PAGE, bounded: true)
    inst = self
    page_number = @filtered_params.fetch(:p, 1).to_i #If no p given, force to 1.
    size = (@filtered_params[:results_per_page] || size).to_i
    size = [size, MAX_RESULTS_PER_PAGE].min
    inst.query[:from] = size * (page_number - 1) rescue 0
    inst.query[:size] = size
    inst
  end

  def append_sort_filters
    sort_keys = [:budget, :popularity, :rent, :date_added, :valuation, :dream_price]
    inst = self
    sort_key = @filtered_params[:sort_key].to_sym rescue nil
    if sort_keys.include? sort_key
      sort_order = @filtered_params[:sort_order] || "asc"
      inst = inst.append_field_sorting(sort_key,sort_order)
    else
      # inst = inst.append_score_view_count_sort
      # inst = inst.user_script_query_sorting("rent")
    end
    inst
  end

  def post_url(query = {}, index_name='property_details', type_name='property_detail')
    uri = URI.parse(URI.encode("http://localhost:9200/#{index_name}/#{type_name}/_search"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body,status
  end

  def self.index_es_records
    start_date = 3.months.ago
    ending_date = 4.hours.ago
    years = (1955..2015).step(10).to_a
    time_frame_years = (2004..2016).step(1).to_a
    days = (1..24).to_a
    body = []
    client = Elasticsearch::Client.new
    characters = (1..10).to_a
    alphabets = ('A'..'Z').to_a
    addresses = get_bulk_addresses
    names = ['John Doe', 'John Smith', 'Garry Edwards']
    scroll_id = 'cXVlcnlUaGVuRmV0Y2g7NTs3MTk2OkNvamwtRG1oUnU2cl9GbC0zSHpFcXc7NzE5NzpDb2psLURtaFJ1NnJfRmwtM0h6RXF3OzcxOTg6Q29qbC1EbWhSdTZyX0ZsLTNIekVxdzs3MTk5OkNvamwtRG1oUnU2cl9GbC0zSHpFcXc7NzIwMDpDb2psLURtaFJ1NnJfRmwtM0h6RXF3OzA7'
    glob_counter = 0
    loop do
      get_records_url = 'http://localhost:9200/_search/scroll'
      p 'hello'
      scroll_hash = { scroll: '15m', scroll_id: scroll_id }
      response , status = post_url_new(scroll_hash)
      udprns = JSON.parse(response)["hits"]["hits"].map { |t| t['_source']['udprn']  }
      break if udprns.length == 0
      
      body = []
      udprns.each do |udprn|
        doc = {}
        RANDOM_SEED_MAP.each do |key, values|
          doc[key] = values.sample(1).first
        end
        doc[:year_built] = doc[:year_built].to_s+"-01-01"
        doc[:date_added] = Time.at((start_date.to_f - ending_date.to_f)*rand + start_date.to_f).utc.strftime('%Y-%m-%d')
        doc[:time_frame] = time_frame_years.sample(1).first.to_s + "-01-01"
        doc[:external_property_size] = doc[:internal_property_size] + 100
        doc[:total_property_size] = doc[:external_property_size] + 100
        doc[:additional_features_type] = [doc[:additional_features_type]]
        doc[:budget] = doc[:price]
        doc[:valuation] = (doc[:price].to_f/(1.3)).to_i
        doc[:valuation_date] = (1..30).to_a.sample(1).first.days.ago.to_date.to_s
        doc[:dream_price] = doc[:price]
        doc[:last_sale_price] = ((doc[:price].to_f)/(2.3)).to_f
        doc[:last_sale_price_date] = (1..5).to_a.sample(1).first.years.ago.to_date.to_s
        doc[:description] = 'Lorem Ipsum'
        doc[:agent_branch_name] = names.sample(1).first
        doc[:assigned_agent_employee_name] = "John Smith"
        doc[:assigned_agent_employee_address] = "5 Bina Gardens"
        doc[:assigned_agent_employee_image] = nil
        doc[:last_updated_date] = "2015-09-21"
        doc[:agent_logo] = "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop.jpg"
        doc[:broker_branch_contact] = "020 3641 4259"
        doc[:date_updated] = 3.days.ago.to_date.to_s
        if doc[:photos] == "Yes"
          doc[:photo_count] = 3
          doc[:photo_urls] = [
            "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop.jpg",
            "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop2.jpg",
            "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop3.jpg",
          ]
        else
          doc[:photo_urls] = []
        end

        doc[:broker_logo] = "http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/prop3.jpg"
        doc[:agent_contact] = "020 3641 4259"
        description = ''
        doc[:description] = characters.sample(1).first.times do
          description += alphabets.sample(1).first
        end
        doc[:interested_in_view] = "/api/v0/vendors/update/property_users?action_type=interested_in_view"
        doc[:request_a_view] = "/api/v0/vendors/update/property_users?action_type=request_a_view"
        doc[:make_offer] = "/api/v0/vendors/update/property_users?action_type=make_offer"
        doc[:follow_street] = "/addresses/follow?location_type=dependent_thoroughfare_description"
        doc[:follow_locality] = "/addresses/follow?location_type =dependent_locality"
        body.push({ update:  { _index: 'addresses', _type: 'address', _id: udprn, data: { doc: doc } }})
      end
      response = client.bulk body: body unless body.empty?
      p response['items'].first
      p "#{glob_counter} pASS completed"
      glob_counter += 1
    end
  end

  def self.post_url_new(query = {}, index_name='property_details', type_name='property_detail')
    uri = URI.parse(URI.encode("http://localhost:9200/_search/scroll"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body, status
  end

  def self.test_search
    errors = []
    FIELDS[:terms].each do |term|
      value = RANDOM_SEED_MAP[term.to_s.singularize.to_sym].sample(1).first rescue nil
      url = "http://localhost/api/v0/properties/search?"
      if value
        query_params = {}
        query_params[term] = value
        query_params = query_params.to_query
        url = url + query_params
        response = Net::HTTP.get_response(URI.parse(url))
        errors.push(term) if response.code.to_i != 200
      else
        errors.push(term)
      end
    end
    p errors

    FIELDS[:term].each do |term|
      value = RANDOM_SEED_MAP[term].sample(1).first rescue nil
      url = "http://localhost/api/v0/properties/search?"
      if value
        query_params = {}
        query_params[term] = value
        query_params = query_params.to_query
        url = url + query_params
        p url
        response = Net::HTTP.get_response(URI.parse(url))
        #p JSON.parse(response.body)["hits"]["total"]
        errors.push(term) if response.code.to_i != 200
      else
        errors.push(term)
      end
    end

    year_fields = [:date_added, :time_frame]
    range_fields = FIELDS[:range] - year_fields

    range_fields.each do |term|
      values = RANDOM_SEED_MAP[term].sample(2) rescue nil
      url = "http://localhost/api/v0/properties/search?"
      if values
        query_params = {}
        query_params["min_"+term.to_s] = values.min
        query_params["max_"+term.to_s] = values.max
        query_params = query_params.to_query
        url = url + query_params
        p url
        response = Net::HTTP.get_response(URI.parse(url))
        # p JSON.parse(response.body)["hits"]["total"]
        errors.push(term) if response.code.to_i != 200
      else
        errors.push(term)
      end
    end

    year_fields.each do |field|
      query_params = {}
      url = "http://localhost/api/v0/properties/search?"
      if field == :date_added
        query_params["min_"+field.to_s] = "2014-01-01 21:00:00"
        query_params["max_"+field.to_s] = "2015-01-01 21:00:00"
      else
        query_params["min_"+field.to_s] = "2014-01-01"
        query_params["max_"+field.to_s] = "2015-01-01"
      end
      query_params = query_params.to_query
      url = url + query_params
      p url
      response = Net::HTTP.get_response(URI.parse(url))
      #p JSON.parse(response.body)["hits"]["total"]
    end
    p errors
  end

  def self.get_bulk_addresses
    query = {
      size: 10000,
      query: {
        match_all: {}
      }
    }
    p = PropertyDetailsRepo.new(filtered_params: {a: :b})
    response, code = p.post_url(query, 'addresses', 'address')
    p code
    JSON.parse(response)['hits']['hits']
  end

  def form_query(str)
    inst = self
    area, sector, district, unit = search_flats_for_postcodes(str)
    if area
      inst.append_term_filter_query('area', area) unless area.nil?
    end
    if district
      inst.append_term_filter_query('district', district) unless area.nil?
    end
    if sector
      inst.append_term_filter_query('sector', sector) unless area.nil?
    end
    if unit
      inst.append_term_filter_query('unit', unit) unless area.nil?
    end
    return inst
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

end

