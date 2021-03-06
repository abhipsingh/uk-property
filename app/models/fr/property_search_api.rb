module Fr
  class PropertySearchApi
  include Elasticsearch::Search
    RESULTS_PER_PAGE = 10
  MAX_RESULTS_PER_PAGE = 200
  ES_EC2_URL = Rails.configuration.remote_es_url
  ES_EC2_HOST = Rails.configuration.remote_es_host
  FIELDS = {
    terms: [ :udprns ],
    term:  [ :udprn, :dl, :dtd, :pt, :county, :property_type, :property_status_type ],
    range: [ :cost_per_month, :beds, :baths, :receptions ],
    not_exists: [ :vendor_id, :agent_id, :property_status_type, :udprn, :postcode, :property_style, :sale_price ],
    exists: []
  }

  ES_ATTRS = [
              :county, :pt, :dl, :dtd, :property_type, :property_status_type, :beds, :baths, :receptions
            ]

  ADDRESS_LOCALITY_LEVELS = [:county, :pt, :dl, :dtd, :td, :building_name, :building_number, :sub_building_name, :udprn ]
  
  #### The list of statuses are 'Green', 'Amber', 'Red'.
  ### Please see the previous commits to see what existed here
  RANDOM_SEED_MAP = {
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
    }
  }

  ### Type of match, Buyer status, Property status

  PROPERTY_MATCH_HASH = {
    'Perfect_Green' => [:dream_price],
    'Perfect_Amber' => [:sale_price],
    'Perfect_Red' => [:sale_price],
    'Potential_Green' => [:sale_price, :dream_price, :property_type],
    'Potential_Red' => [:dream_price, :sale_price, :property_type],
    'Potential_Amber' => [:dream_price, :sale_price, :property_type],
  }

  SEARCH_CONSTRAINTS_MAP = {
    county: [:county],
    post_town: [:pt, :county],
    dependent_locality: [:pt, :county, :dl],
    dependent_thoroughfare_description: [:pt, :county, :dl, :dtd]
  }

  FR_POST_TOWN_MAP = JSON.parse(File.read("fr_post_town_county_map.json"))

  FR_COUNTIES = FR_POST_TOWN_MAP.values.uniq
  FR_POST_TOWNS = FR_POST_TOWN_MAP.keys.uniq

  def initialize(options={})
    @filtered_params = options[:filtered_params].symbolize_keys
    @query = self.class.append_empty_hash
    @query = options[:query] if @is_query_custom == true
  end

  def apply_filters
    inst = self
    inst.adjust_size
    inst.adjust_included_fields
    inst = inst.append_pagination_filter
    # inst = inst.append_hash_filter
    inst = inst.append_sort_filters
    inst = inst.append_terms_filters
    inst = inst.append_term_filters
    inst = inst.append_range_filters
    inst = inst.append_exists_filters
    inst = inst.append_not_exists_filters
    shift_query_keys
    #Rails.logger.info(inst.filtered_params)
    # Rails.logger.info(inst.query)
  end

  def apply_filters_except_hash_filter
    apply_filters
  end

  def shift_query_keys
    query_clone = @query.deep_dup
    @query = {}
    @query[:size] = query_clone[:size]
    @query[:from] = query_clone[:from]
    keys = query_clone.keys - [:size, :from]
    keys.each do |key|
      @query[key] = query_clone[key]
    end
  end

  def filter
    body = []
    status = 200  
    inst = self
    modify_filtered_params
    inst.apply_filters
    inst.modify_query
    body, status = fetch_data_from_es
    return { results: body }, status
  end

  def filter_query
    inst = self
    modify_filtered_params
    inst.apply_filters
    inst.modify_query
    inst
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
    # Rails.logger.info(inst.query)
    udprns, status = fetch_udprns
    body = fetch_details_from_udprns(udprns)
    return body, status
  end

  def increase_size_filter
    @query[:size] = 10000
  end

  def fetch_udprns(count_flag=false)
    inst = self
    udprns = []
    range_fields = FIELDS[:range].map{|t| ["max_#{t.to_s}".to_sym, "min_#{t.to_s}".to_sym] }.flatten

    exists_filtered_keys = @filtered_params[:exists].split(',').map(&:to_sym) if @filtered_params[:exists].is_a?(String)
    exists_filtered_keys ||= []

    not_exists_filtered_keys = @filtered_params[:not_exists].split(',').map(&:to_sym) if @filtered_params[:not_exists].is_a?(String)
    not_exists_filtered_keys ||= []

    if @filtered_params[:listing_type] && @filtered_params[:udprns]
      udprns = @filtered_params[:udprns].split(',')
      status = 200
    elsif @filtered_params[:udprn]
      udprns = [ @filtered_params[:udprn] ]
    elsif ((((FIELDS[:terms] + FIELDS[:term] + range_fields + FIELDS[:not_exists] + FIELDS[:exists]) - ADDRESS_LOCALITY_LEVELS ) & ( @filtered_params.keys + exists_filtered_keys + not_exists_filtered_keys )).empty?) &&  @filtered_params[:sort_key].nil?
      Rails.logger.info("Hello")
      udprns, status = search_from_primary_db(count_flag)
    else
      Rails.logger.info("ES_QUERY_#{inst.query}")
      
      body, status = nil
      if count_flag
        Rails.logger.info("QUERY_#{inst.query}")
        body, status = post_url(inst.query, Rails.configuration.fr_address_index_name, Rails.configuration.fr_address_type_name, '_search?search_type=count')
        udprns = Oj.load(body)['hits']['total']
      else
        body, status = post_url(inst.query, Rails.configuration.fr_address_index_name, Rails.configuration.fr_address_type_name)
        parsed_body = Oj.load(body)['hits']['hits']
        udprns = parsed_body.map { |e|  e['_id'] }
        @total_count = Oj.load(body)['hits']['total']
  
        ### If count of udprns is zero and no filters have been selected(only sort by)
        ### then first get the results and the intended page number and adjust limit 
        ### offset accordingly
        if udprns.count == 0 && ((((FIELDS[:terms] + FIELDS[:term] +range_fields + FIELDS[:not_exists] + FIELDS[:exists]) - ADDRESS_LOCALITY_LEVELS - POSTCODE_LEVELS) & ( @filtered_params.keys + exists_filtered_keys + not_exists_filtered_keys )).empty?) && @filtered_params[:sort_key] == 'status_last_updated'
          ### Only get the count of results in es
          body, status = post_url(inst.query, Rails.configuration.fr_address_index_name, Rails.configuration.fr_address_type_name, '_search?search_type=count')
          total_count = Oj.load(body)['hits']['total']
  
          primary_db_page_number = @filtered_params[:p].to_i - ((total_count/RESULTS_PER_PAGE).to_i)
          @filtered_params[:p] = primary_db_page_number
          inst = self
          inst = inst.append_pagination_filter
          udprns, status = search_from_primary_db(count_flag)
        end
      end
    end
    return udprns, status
  end
  
  def fetch_details_from_udprns(udprns)
    body = PropertyService.bulk_details_fr(udprns)    
    return body
  end

  def modify_query
    if @filtered_params.has_key?(:match_type)
      type_of_match = @filtered_params[:match_type]
      modify_type_of_match_query(type_of_match)
    end
  end

  def modify_range_params
    similar_names = {
      budget: [:current_valuation, :dream_price]
    }
    similar_names.each do |key, similar_values|
      similar_values.each do |similar_value|
        modify_similar_value_in_params(key, similar_value)
      end
    end
  end

  def self.construct_hash_from_hash_str(hash)
    address_levels = hash[:hash_str].split('|')[0]
    arr = address_levels.split('_')
    ADDRESS_LOCALITY_LEVELS.each_with_index do |level, index|
      hash[level] = arr[index] if !arr[index].nil? && arr[index] != '@'
    end
  end

  def search_from_primary_db(count_flag=false)
    query = Fr::Property
    mvc = MatrixViewService.new(hash_str: @hash_key)
    search_columns = SEARCH_CONSTRAINTS_MAP[mvc.level]
    search_column_hash = {
      pt: :post_town,
      county: :county,
      dl: :dependent_locality,
      dtd: :dependent_thoroughfare_description
    }

    if search_columns
      postcode = nil

      address_columns = search_columns
      address_columns.each do |addr_col|
        value = nil
        column = MatrixViewCount::FR_COLUMN_MAP[addr_col]
        params_key = search_column_hash[column.to_sym]
        Rails.logger.info("Hello_#{mvc.context_hash[params_key]}")
        value = FR_POST_TOWNS.index(mvc.context_hash[params_key].upcase)  if addr_col == :pt && mvc.context_hash[params_key]
        value = FR_COUNTIES.index(mvc.context_hash[params_key]) if addr_col == :county && mvc.context_hash[params_key]
        value ||= mvc.context_hash[params_key]
        if value
          if (addr_col == :dl || addr_col == :dtd)
            #query = query.where("md5(#{column}) = md5(?)", value) 
            query = query.where("#{column} = ?", value) 
          else
           query = query.where("#{column} = ?", value)
          end
        else
          query = query.where("#{column} IS ?", value) if !value
        end
      end
    else
      return [], 200
    end
    Rails.logger.info("QUERY_#{query.to_sql}")
    udprns, status = execute_search_primary_db(query, count_flag)
    return udprns, status
  end

  def execute_search_primary_db(query, count=false)
    #### Paginate
    udprns = nil
    status = 200
    PropertyAddress.connection.execute("set enable_seqscan to off;")
    if !count 
      query = query.limit(@query[:size].to_i) if @query[:size]
      query = query.offset(@query[:from].to_i)
      udprns = query.pluck(:udprn)
    else
      udprns = query.count
    end
    PropertyAddress.connection.execute("set enable_seqscan to on;")
    return udprns, status
  end

  def modify_filtered_params_hash_str
    ### For hash str
    ### Change the filtered params in such a way that hashes are not used at all
    Rails.logger.info("FILTERED_PARAMS_#{@filtered_params}")
    if @filtered_params.has_key?(:hash_str) && @filtered_params.has_key?(:hash_type)
      self.class.construct_hash_from_hash_str(@filtered_params)
    end
    
    @hash_key ||= @filtered_params[:hash_str]

    if @filtered_params.has_key?(:listing_type) && !@filtered_params[:listing_type].nil?
      ad_type = PropertyAd::TYPE_HASH[@filtered_params[:listing_type]]
      service = nil
      udprns = PropertyAd.where(hash_str: @filtered_params[:hash_str], service: 1, ad_type: ad_type).pluck(:property_id) ### Currently only buy
      @filtered_params[:udprns] = udprns.join(',')
      @filtered_params.delete(:udprn)
    end

    if @filtered_params[:post_town]
      @filtered_params[:post_town] = @filtered_params[:post_town].split(' ').map{|t| if t.downcase != 'and' then t.capitalize else t.downcase end }.join(' ')
    end

    #@filtered_params[:sort_key] = :building_number if @filtered_params[:sort_key].nil?
    #@filtered_params[:sort_order] = 'desc' if @filtered_params[:sort_order].nil?

    @filtered_params.delete(:hash_str)
    @filtered_params.delete(:hash_type)
    @filtered_params.delete(:county) if !@filtered_params[:post_town].nil?
  end

  def modify_filtered_params
    modify_range_params
    modify_filtered_params_hash_str
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
    fields = PROPERTY_MATCH_HASH["#{type_of_match}_#{property_status_type}"]
    fields ||= []
    @query[:filter] ||= { and: { filters: [] }}
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

  def add_not_exists_filter(term)
    add_exists_filter(term)
    last_query = @query[:filter][:and][:filters].last
    not_query = { not: last_query }
    @query[:filter][:and][:filters].pop
    @query[:filter][:and][:filters].push(not_query)
  end

  def append_term_filters
    inst = self
    term_filters = @filtered_params.keys & FIELDS[:term]
    Rails.logger.info("#{term_filters}___#{@filtered_params}")
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

  def append_not_exists_filters
    inst = self
    not_exists_filters = @filtered_params[:not_exists].split(',').map(&:to_sym) & FIELDS[:not_exists] if @filtered_params[:not_exists].is_a?(String)
    not_exists_filters.each{ |t| inst.append_not_exists_filter(t.to_sym) } if not_exists_filters
    inst
  end

  def append_exists_filters
    inst = self
    exists_filters = @filtered_params[:exists].split(',').map(&:to_sym) & FIELDS[:exists] if @filtered_params[:exists].is_a?(String)
    exists_filters.each{ |t| inst.append_exists_filter(t.to_sym) } if exists_filters
    inst
  end

  def append_terms_filters
    inst = self
    terms_filters = @filtered_params.keys & FIELDS[:terms]
    terms_filters.each{|t|  inst = inst.append_terms_filter_query(t.to_s.singularize, @filtered_params[t].split(","), :and) if @filtered_params[t]}
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

  #### Please see the commit logs to check the history of this method
  ### def append_premium_or_featured_filter

  def append_sort_filters
    sort_keys = [ :budget, :popularity, :rent, :date_added, :current_valuation, :dream_price, :status_last_updated, :building_number, :last_sale_price, 
                  :status_last_updated, :price, :sale_price ]
    inst = self
    sort_key = @filtered_params[:sort_key].to_sym rescue nil
    if sort_keys.include? sort_key
      sort_order = @filtered_params[:sort_order] || "asc"
      inst = inst.append_field_sorting(sort_key,sort_order)
      inst = inst.append_exists_filter(sort_key)
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
    body = []
    client = Elasticsearch::Client.new host: ES_EC2_HOST
    scroll_id = scroll_id
    glob_counter = 0
    loop do
      scroll_hash = { scroll: '240m', scroll_id: scroll_id }
      response , _status = post_url_new(scroll_hash)
      response_arr = Oj.load(response)['hits']['hits'].map { |e| e['_source'] }
      break if response_arr.length == 0
      body = []
      response_arr.each_with_index do |each_response, index|
        ### Please see from the past commits to see the history of this method
        # process_doc_with_conditions(doc)
      end
      # p response['items'].first
      p "#{glob_counter} pASS completed for #{body.count} ITEMS"
      glob_counter += 1
    end
  end

  ### See past commits to check the method
  def self.process_doc_with_conditions(doc)
  end

  def self.transfer_data_from_es_to_key_value_store(scroll_id)
    scroll_id = scroll_id
    glob_counter = 0
    #Rails.configuration.ardb_client.flushall
    batch = 0
    loop do
      scroll_hash = { scroll: '240m', scroll_id: scroll_id }
      response, _status = post_url_new(scroll_hash)
      response_arr = Oj.load(response)['hits']['hits'].map { |e| e['_source'] }
      break if response_arr.length == 0
      body = []
      response_arr.each { |res| PropertyService.update_udprn(res['udprn'], res) }
      p "Batch #{batch} completed"
      batch += 1
    end
  end
 
  ### Used for getting matched properties (count only)
  def matching_property_count
    inst = self
    inst.adjust_size
    inst.modify_filtered_params
    inst.apply_filters
    inst.modify_query
    count, status = fetch_udprns(true)
    return count, status
  end

  ### Get the matching udprns only
  def matching_udprns
    inst = self
    inst.filter_query
    udprns, status = fetch_udprns
    return udprns, status
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
  end
end

