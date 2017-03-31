require 'base64'
class PropertySearchApi
  include Elasticsearch::Search
  NEARBY_DEFAULT_RADIUS = 1500
  NEARBY_MAX_RADIUS = 5000
  RESULTS_PER_PAGE = 20
  MAX_RESULTS_PER_PAGE = 150
  ES_EC2_URL = Rails.configuration.remote_es_url
  ES_EC2_HOST = Rails.configuration.remote_es_host
  FIELDS = {
    terms: [ :property_types, :monitoring_types, :property_status_types, :parking_types, :outside_space_types, :additional_feature_types, :keyword_types, :udprns, :vendor_ids, :postcodes, :post_codes ],
    term:  [ :tenure, :epc, :property_style, :listed_status, :decorative_condition, :central_heating, :photos, :floorplan, :chain_free, :council_tax_band, :verification, :property_brochure, :new_homes, :retirement_homes, :shared_ownership, :under_off, :verification_status, :agent_id, :district, :udprn, :vendor_id, :postcode, :sector, :unit, :building_name, :building_number, :sub_building_name, :post_code, :ads, :accepting_quotes ],
    range: [ :cost_per_month, :date_added, :floors, :year_built, :internal_property_size, :external_property_size, :total_property_size, :improvement_spend, :time_frame, :beds, :baths, :receptions, :current_valuation, :dream_price ],
  }

  #### The list of statuses are 'Green', 'Amber', 'Red'.

  STREET_VIEW_URLS = [
    "https://s3-us-west-2.amazonaws.com/propertyuk/0000196e88581b8e149fcdedfa2f09a63ac73886.jpg",
    "https://s3-us-west-2.amazonaws.com/propertyuk/00001f4db96b63762cd64500458c6dedb22100a6.jpg",
    "https://s3-us-west-2.amazonaws.com/propertyuk/00002f32044b5d8e6b6a4acc5a51afb3ecb75268.jpg",
    "https://s3-us-west-2.amazonaws.com/propertyuk/0000316abcb9f9cac277ab59c63e975b4af40177.jpg"
  ]

  STREET_VIEW_UDPRNS = [ 21724275, 53478695, 2962965, 25400727, 6711263, 26544243, 470169, 11292578, 4359896, 25867127 ]

  AGENT_LOGOS = [ 4523, 4524, 4525, 4526, 4527, 4528, 4529, 4530, 4531, 4532 ]
  TIMES = (1..10).to_a
  UNITS = ['minutes', 'hours', 'seconds']
  PRICE_TYPES = [:fixed_price, :asking_price, :offers_over]

  AGENT_PROFILE_IMAGE_URLS = [
    "https://st.zoocdn.com/zoopla_static_agent_logo_(66951).png",
    "https://st.zoocdn.com/zoopla_static_agent_logo_(44631).data"
  ]

  DESCRIPTIONS = ['We are delighted to offer this well maintained modern two bedroom purpose built flat situated within easy walking distance of Barking Town Centre. Property benefits from recent redecoration throughout and would idealy suit a professional couple or small working family.

This two bedroom second floor flat has been lovingly redecorated throughout and boasts two double bedrooms, main bedroom is fitted, a luxury bathroom wc with shower over bath, modern fitted kitchen with appliances and a spacious L shaped lounge/ diner. The property benefits from allocated parking and communal gardens. Located just few minutes walk from Barking station. Your earliest inspection in advised.', 'This recently refurbished two double bedroom top floor flat with lift access offers spacious, bright and airy accomodation throughout. Located in this convenient position close to transport links with easy access to Barking town centre.

Call now to view this recently renovated two bedroom flat which benefits from a new fitted kitchen and luxury bathroom wc. This property boasts two double bedrooms a spacious livingroom with direct access balcony, a newly kitchen with appliances, a luxury bathroom wc with shower over bath. Outside is communal gardens and own garage.', 'Call now to view this one bedroom first floor flat located in this popular location, opposite Barking Station, this property has been well maintained throughout and is available now.

Bairstow Eves are pleased to offer this lovely one bedroom apartment located across the road from Barking station. The property benefits from a good size reception room open plan to kitchen area with direct access to the roof terrace. Other features include a fitted bathroom, electric heating, double glazing, security entry phone system and concierge service and the added benefit of secure underground parking.']

  NAMES = ['Boris Stuart', 'John Smith', 'Adam Galloway']

  RANDOM_SEED_MAP = {
    property_type: ["Barn conversion","Bungalow","Cottage","Country house","Detached house","Detached bungalow","End terrace house","Equestrian property","Farm","Barn conversion/farmhouse","Farmhouse","Flat","Houseboat","Link-detached house","Lodge","Maisonnette","Mews house","Mobile/park home","Semi-detached house","Semi-detached bungalow","Studio","Terraced house","Terraced bungalow","Town house"],
    property_status_type: ["Green", "Amber", "Red"],
    verification_status: [ true, false ],
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
    floorplan: ["Yes", "No"],
    street_view_image_url: STREET_VIEW_URLS,
    agent_employee_profile_image: AGENT_PROFILE_IMAGE_URLS,
    agent_employee_name: ['John Adams', 'John Smith', 'John Clarke'],
    agent_employee_mobile_number: ['9876543210', '4567890123', '345780921'],
    agent_employee_email_address: ['a@b.com', 'b@c.com', 'c@d.com'],
    added_by: ['Us']
  }

  BUYER_STATUS_HASH = {
    'Perfect' => {
      'Green' => ['Green', 'Amber', 'Red'],
      'Amber' => ['Amber', 'Red'],
      'Red' => []
    },
    'Potential' => {
      'Green' =>  ['Amber', 'Red'],
      'Amber' => ['Amber', 'Red', 'Green'],
      'Red' => []
    },
    'Normal' => {
      'Green' => ['Amber', 'Red', 'Green'],
      'Amber' => ['Amber', 'Red', 'Green'],
      'Red' => ['Amber', 'Red', 'Green']
    }
  }

  ### Type of match, Buyer status, Property status

  PROPERTY_MATCH_HASH = {
    'Perfect_Green_Green' => [],
    'Perfect_Green_Amber' => [],
    'Perfect_Green_Red' => [],
    'Perfect_Amber_Amber' => [],
    'Perfect_Amber_Red' => [],
    'Potential_Green_Amber' => [:dream_price],
    'Potential_Green_Red' => [:dream_price],
    'Potential_Amber_Green' => [:dream_price],
    'Potential_Amber_Amber' => [:dream_price],
    'Potential_Amber_Red' => [:dream_price]
  }

  def initialize(options={})
    # index = options[:index] || 'property_details'
    # client = Elasticsearch::Client.new url: options[:url], log: options[:log]
    @filtered_params = options[:filtered_params].symbolize_keys
    @query = self.class.append_empty_hash
    @query = options[:query] if @is_query_custom == true
  end

  def apply_filters
    inst = self
    inst.adjust_size
    inst.adjust_included_fields
    inst = inst.append_pagination_filter
    inst = inst.append_hash_filter
    inst = inst.append_terms_filters
    inst = inst.append_term_filters
    inst = inst.append_range_filters
    inst = inst.append_sort_filters
    # inst
    Rails.logger.info(inst.query)
  end

  def filter
    inst = self
    modify_filtered_params
    append_premium_or_featured_filter
    inst.apply_filters
    inst.modify_query
    body, status = fetch_data_from_es
    return { results: body }, status
  end

  def adjust_size
    if @filtered_params.has_key?(:limit)
      @query[:size] = [@filtered_params[:limit], 1000].min
    elsif @filtered_params.has_key?(:count) && @filtered_params[:count] == 'true'
      @query[:size] = 0
    end
  end

  def adjust_included_fields
    if @filtered_params.has_key?(:fields)
      @query[:_source] = { include: @filtered_params[:fields].split(',') }
    end
  end

  def fetch_data_from_es
    inst = self
    # Rails.logger.info(inst.query)
    body, status = post_url(inst.query, Rails.configuration.address_index_name, Rails.configuration.address_type_name)
    body = Oj.load(body)['hits']['hits'].map do |t|
      ## TODO - Confirm this
      # t['_source']['score'] = t['matched_queries'].count
      t['_source']
    end
    return body, status
  end

  def modify_query
    if @filtered_params.has_key?(:match_type)
      type_of_match = @filtered_params[:match_type]
      modify_type_of_match_query(type_of_match)
    end
  end

  def modify_filtered_params
    similar_names = {
      budget: [:current_valuation, :dream_price]
    }
    similar_names.each do |key, similar_values|
      similar_values.each do |similar_value|
        modify_similar_value_in_params(key, similar_value)
      end
    end
  end

  def modify_similar_value_in_params(key, similar_value)
    if @filtered_params.has_key?(key)
      @filtered_params[similar_value] = @filtered_params[key]
    elsif @filtered_params.has_key?("max_#{key}".to_sym)
      @filtered_params["max_#{similar_value}".to_sym] = @filtered_params["max_#{key}".to_sym].to_i
    elsif @filtered_params.has_key?("min_#{key}".to_sym)
      @filtered_params["min_#{similar_value}".to_sym] = @filtered_params["min_#{key}".to_sym].to_i
    end
  end

  def modify_type_of_match_query(type_of_match)
    buyer_status = @filtered_params[:buyer_status]
    property_status_types = ['Red', 'Amber', 'Green']
    queries = []
    property_status_types.each do |property_status_type|
      queries.push(form_partial_query(property_status_type, buyer_status, type_of_match))
    end
    @query[:filter] = { or: { filters: queries }}
  end

  def form_partial_query(property_status_type, buyer_status, type_of_match)
    or_skeletion = basic_and_query.clone
    fields = PROPERTY_MATCH_HASH["#{type_of_match}_#{buyer_status}_#{property_status_type}"]
    fields ||= []
    original_query = @query[:filter][:and][:filters]
    new_query = original_query.clone
    fields.map { |field| modify_query_for_field(field, original_query, new_query) }
    property_status_query = { term: { property_status_type: property_status_type } }
    new_query.push(property_status_query)
    or_skeletion[:and][:filters] = new_query
    or_skeletion
  end

  def modify_query_for_field(field, original_query, new_query)
    field_query = new_query.select{ |v| v.values.first[:_name].to_s.to_sym == field.to_sym }.first
    if field_query
      new_or_query = basic_or_query.clone
      new_query.reject!{ |v| v.values.first[:_name].to_s.to_sym == field.to_sym }
      type_of_query = field_query.keys.first
      negative_query_for_type(type_of_query.to_sym, field_query, new_or_query)
      new_query.push(new_or_query)
    end
  end

  def negative_query_for_type(type_of_query, field_query, new_or_query)
    if type_of_query == :range
      max_value = field_query[:range].values.first[:to]
      min_value = field_query[:range].values.first[:from]
      attribute = field_query[:range].keys.first
      if max_value && min_value
        new_or_query[:or][:filters].push({ range: { attribute => { to: min_value }}})
        new_or_query[:or][:filters].push({ range: { attribute => { from: max_value }}})
      elsif max_value
        new_or_query[:or][:filters].push({ range: { attribute => { from: max_value }}})
      elsif min_value
        new_or_query[:or][:filters].push({ range: { attribute => { to: min_value }}})
      end
    elsif type_of_query == :term
      value = field_query[:term].values.first
      attribute = field_query[:term].keys.first
      new_or_query[:or][:filters].push({ not: { filter: { term: { attribute => value }}}})
    elsif type_of_query == :terms
      values = field_query[:terms].values.first
      attribute = field_query[:terms].keys.first
      new_or_query[:or][:filters].push({ not: { filter: { terms: { attribute => values, execution: :and }}}})
    end
  end
  
  def add_exists_filter(term)
    @query[:filter][:and][:filters].push({exists: {field: term}})
  end

  def append_hash_filter
    inst = self
    if filtered_params[:hash_str]
      if filtered_params[:hash_type] == 'postcode'
        inst = form_query(filtered_params[:hash_str])
      else
        inst = inst.append_terms_filter_query('hashes', filtered_params[:hash_str].split('|'), :and)
      end
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

  def make_or_filters(attributes)
    or_filters = @query[:filter][:and][:filters].select{ |k| attributes.include?(k.values[0][:_name]) }
    and_filters = @query[:filter][:and][:filters].select{ |k| !attributes.include?(k.values[0][:_name]) }
    @query[:filter][:and][:filters] = and_filters
    @query[:filter][:and][:filters].push({
      or: {
        filters: or_filters
      }
    })
  end

  def append_pagination_filter(size = RESULTS_PER_PAGE, bounded: true)
    inst = self
    #Rails.logger.info(@filtered_params.fetch(:p, 1))
    page_number = @filtered_params.fetch(:p, 1).to_i #If no p given, force to 1.
    size = (@filtered_params[:results_per_page] || size).to_i
    size = [size, MAX_RESULTS_PER_PAGE].min
    inst.query[:from] = size * (page_number - 1) rescue 0
    inst.query[:size] = size
    #Rails.logger.info(inst.query)
    inst
  end

  def append_premium_or_featured_filter
    inst = self
    if @filtered_params.has_key?(:hash_type) && @filtered_params.has_key?(:hash_str)
      @filtered_params[:listing_type] = 'Normal' if @filtered_params[:listing_type].nil?
      search_str = @filtered_params[:hash_str].to_s + '|' + @filtered_params[:listing_type].to_s
      inst.append_term_filter_query(:match_type_str, search_str, :and)
    end
  end

  def append_sort_filters
    sort_keys = [:budget, :popularity, :rent, :date_added, :valuation, :dream_price, :status_last_updated]
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

  def post_url(query = {}, index_name='property_details', type_name='property_detail', endpoint='_search')
    uri = URI.parse(URI.encode("#{ES_EC2_URL}/#{index_name}/#{type_name}/#{endpoint}"))
    query = (query == {}) ? "" : query.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    result = http.post(uri,query)
    body = result.body
    status = result.code
    return body, status
  end

  def self.index_es_records(scroll_id)
    start_date = 3.months.ago
    ending_date = 4.hours.ago
    # years = (1955..2015).step(10).to_a
    time_frame_years = (2004..2016).step(1).to_a
    # days = (1..24).to_a
    body = []
    client = Elasticsearch::Client.new host: ES_EC2_HOST
    characters = (1..10).to_a
    alphabets = ('A'..'Z').to_a
    # addresses = get_bulk_addresses
    names = Agent.last(10).map{ |t| t.name }
    # google_api_crawler = GoogleApiCrawler.new
    scroll_id = scroll_id
    glob_counter = 0
    loop do
      # get_records_url = ES_EC2_URL + '/_search/scroll'
      scroll_hash = { scroll: '30m', scroll_id: scroll_id }
      response , _status = post_url_new(scroll_hash)
      udprns = JSON.parse(response)["hits"]["hits"].map { |t| t['_source']['udprn']  }
      response_arr = Oj.load(response)['hits']['hits'].map { |e| e['_source'] }
      break if udprns.length == 0
      
      body = []
      udprns.each_with_index do |udprn, index|
        doc = {}
        doc[:property_status_type] = 'Unknown'
        hash_value = response_arr[index]['hashes'].last
        building_text = "";
        building_text = building_text + response_arr[index]['building_number'] + " " if response_arr[index]['building_number']
        building_text = building_text + response_arr[index]['building_name'] + " " if response_arr[index]['building_name']
        building_text = building_text + response_arr[index]['sub_building_name'] + " " if response_arr[index]['sub_building_name']
        building_text = building_text[0..building_text.length-2] if building_text[building_text.length-1] == " "
        hashes = response_arr[index]['hashes']
        hash_value = hash_value + '_' + building_text
        hashes.push(hash_value)
        doc['hashes'] = hashes
        match_type_strs = response_arr[index]['match_type_str']
        match_type_strs.push(hash_value+'|Normal')
        doc['match_type_str'] = match_type_strs
         RANDOM_SEED_MAP.each do |key, values|
           doc[key] = values.sample(1).first
         end
        doc[:address] = PropertyDetails.address(response_arr[index])
        doc[:year_built] = doc[:year_built].to_s+"-01-01"
        doc[:date_added] = Time.at((start_date.to_f - ending_date.to_f)*rand + start_date.to_f).utc.strftime('%Y-%m-%d')
        doc[:time_frame] = time_frame_years.sample(1).first.to_s + "-01-01"
        doc[:external_property_size] = doc[:internal_property_size] + 100
        doc[:total_property_size] = doc[:external_property_size] + 100
        doc[:additional_features_type] = [doc[:additional_features_type]]
        doc[:current_valuation] = (doc[:price].to_f/(1.3)).to_i
        doc[:valuation_date] = (1..30).to_a.sample(1).first.days.ago.to_date.to_s
        dream_price_greater_than_valuation = [true, false].sample
        if dream_price_greater_than_valuation
          doc[:dream_price] = (1.1 * doc[:price]).to_i
        else
          doc[:dream_price] = (0.9 * doc[:price]).to_i
        end
        doc[:dream_price] = doc[:price]
        doc[:last_sale_price] = ((doc[:price].to_f)/(2.3)).to_f
        doc[:last_sale_price_date] = (1..5).to_a.sample(1).first.years.ago.to_date.to_s
        doc[:description] = 'Lorem Ipsum'
        doc[:agent_branch_name] = names.sample(1).first
        doc[:assigned_agent_employee_name] = NAMES.sample(1).first
        doc[:assigned_agent_employee_address] = "5 Bina Gardens"
        doc[:assigned_agent_employee_image] = nil
        doc[:last_updated_date] = "2015-09-21"
        # doc[:agent_logo] = "http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/prop.jpg"
        doc[:broker_branch_contact] = "020 3641 4259"
        doc[:date_updated] = 3.days.ago.to_date.to_s
        # doc[:agent_id] = 1234
        if doc[:photos] == "Yes"
          doc[:photo_count] = 0
          doc[:photo_urls] = []
        else
          doc[:photo_urls] = []
        end

        # doc[:broker_logo] = "http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/prop3.jpg"
        doc[:agent_contact] = "020 3641 4259"
        description = ''
        doc[:description] = characters.sample(1).first.times do
          description += alphabets.sample(1).first
        end
        ### Process last sale price
        doc[:last_sale_price] = (doc[:price] * 0.7).to_i

        # ### Status last updated
        # doc[:status_last_updated] = (150..365).to_a.sample.days.ago.to_time.strftime("%Y-%m-%d %H:%M:%S").to_s

        # ### Last verified on
        # doc[:verification_time] = (150..365).to_a.sample.days.ago.to_time.strftime("%Y-%m-%d %H:%M:%S").to_s

        # process_doc_with_conditions(doc)

        body.push({ update:  { _index: Rails.configuration.address_index_name, _type: 'address', _id: udprn, data: { doc: doc } }})
      end
      response = client.bulk body: body unless body.empty?
      p response['items'].first
      p "#{glob_counter} pASS completed"
      glob_counter += 1
    end
  end

  def self.random_time
    number = TIMES.sample(1).first
    unit = UNITS.sample(1).first
    str = "#{number} #{unit} ago"
  end

  def self.process_doc_with_conditions(doc)
    #### Street view is common to all
    street_view_updrn = STREET_VIEW_UDPRNS.sample(1).first
    street_view_url = "https://s3-us-west-2.amazonaws.com/propertyuk/#{street_view_updrn}_street_view.jpg"

    ### Street view url is random for both the images
    doc[:photos] = [street_view_url]
    doc[:street_view_image_url] = street_view_url

    ############### Generic for all verified and unverified properties
    if doc[:verification_status] == true

      ### Agent logo
      agent_id =  AGENT_LOGOS.sample(1).first
      doc[:agent_logo] = "https://s3-us-west-2.amazonaws.com/propertyuk/agent_logo_#{agent_id}.jpg"
      doc[:broker_logo] = "https://s3-us-west-2.amazonaws.com/propertyuk/agent_logo_#{agent_id}.jpg"

      ### listing updated
      doc[:last_listing_updated] = random_time

      ### Types of property
      property_types = [ 'Semi-detached house', 'Detached house', 'Flat', 'Terraced house' ]
      doc[:property_type] = property_types.sample(1).first

      ### Tenure
      tenure = ['Freehold', 'Leasehold'].sample(1).first
      doc[:tenure] = tenure

      ### Descriptions
      description = DESCRIPTIONS.sample(1).first
      doc[:description] = description

      ### Green property status type specific fields
      if doc[:property_status_type] == 'Green'
        price_type = PRICE_TYPES.sample(1).first
        doc[price_type] = doc[:price]
      elsif doc[:property_status_type] == 'Amber'
        doc[:current_valuation] = doc[:price]
      end

      ### Date of valuation
      doc[:valuation_date] = (1..365).to_a.sample.days.ago.to_date.to_s

      ### Price last updated
      doc[:price_last_updated] = (1..365).to_a.sample.days.ago.to_time.strftime("%Y-%m-%d %H:%M:%S").to_s

      ### Handle the case where verification status is still pending
    else
      ### Agent logo
      doc[:agent_logo] = nil
      doc[:broker_logo] = nil

      ### Valuation
      historical_detail = PropertyHistoricalDetail.where(udprn: doc[:udprn]).last
      doc[:valuation] = historical_detail.price
      doc[:valuation_date] = historical_detail.date.split(' ')[0] rescue nil

      ### Beds, baths and receptions
      doc[:beds] = nil
      doc[:baths] = nil
      doc[:receptions] = nil

      ### Types of property
      doc[:property_type] = nil

      ### Tenure
      doc[:tenure] = nil

      ### Property size
      doc[:internal_property_size] = nil
      doc[:external_property_size] = nil
      doc[:total_property_size] = nil

      ### Description
      doc[:description] = nil

      ### listing updated
      doc[:last_listing_updated] = random_time

      ### Last sale date
      doc[:last_sale_date] = (1..365).to_a.sample.days.ago.to_date.to_s

      ### Price last updated
      doc[:price_last_updated] = nil

    end
    
  end
 
  ### Used for getting matched properties (count only)
  def matching_property_count
    inst = self
    inst.adjust_size
    inst = inst.append_hash_filter
    body, status = post_url(inst.query, Rails.configuration.address_index_name, Rails.configuration.address_type_name, '_search?search_type=count')
    count = Oj.load(body)['hits']['total'] rescue 0
    return count, status
  end
  

  def self.post_url_new(query = {}, index_name='property_details', type_name='property_detail')
    uri = URI.parse(URI.encode("#{ES_EC2_URL}/_search/scroll"))
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
      url = "#{ES_EC2_URL}/api/v0/properties/search?"
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
    p = PropertySearchApi.new(filtered_params: {a: :b})
    response, code = p.post_url(query, Rails.configuration.address_index_name, 'address')
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

### API calls for perfect, potential and unlikely matches
### http://localhost:3000/api/v0/properties/search?property_style=Period&hash_str=LIVERPOOL&hash_type=Text&type_of_match=Unlikely&min_valuation=2&max_valuation=243000&min_total_property_size=240&max_total_property_size=3600000&property_types=Bungalow&min_beds=2&max_beds=3&min_receptions=2&max_receptions=3&min_baths=2&max_baths=3&buyer_status=Red&max_dream_price=240000&min_dream_price=100
