class MatrixViewService
  attr_accessor :hash_str, :level, :context_hash
  POSTCODE_MATCH_MAP = { 
    'unit' => [
      ['unit', 'sector'],
      ['dependent_thoroughfare_description', 'sector'],
      ['thoroughfare_description', 'sector']
    ],  
    'sector' => [
      ['unit', 'sector'],
      ['dependent_thoroughfare_description', 'sector'],
      ['thoroughfare_description', 'sector'],
      ['dependent_locality', 'district'],
      ['sector', 'district']
    ],  
    'district' => [
      ['sector', 'district'],
      ['dependent_locality', 'district'],
      ['post_town', 'district'],
      ['district', 'post_town']
    ]
  }

  ADDRESS_UNIT_MATCH_MAP = {
    'unit' => [
      ['dependent_thoroughfare_description', 'sector'],
      ['thoroughfare_description', 'sector'],
      ['unit', 'sector']
    ],
    'dependent_thoroughfare_description' => [
      ['dependent_thoroughfare_description', 'district'],
      ['thoroughfare_description', 'district'],
      ['unit', 'dependent_thoroughfare_description']
    ],
    'thoroughfare_description' => [
      ['dependent_thoroughfare_description', 'district'],
      ['thoroughfare_description', 'district'],
      ['unit', 'thoroughfare_description']
    ],
    'dependent_locality' => [
      ['dependent_thoroughfare_description', 'dependent_locality'],
      ['thoroughfare_description', 'dependent_locality'],
      ['dependent_locality', 'post_town'],
      ['sector', 'dependent_locality']
    ],
    'post_town' => [
      ['dependent_locality', 'post_town'],
      ['post_town', 'county'],
      ['district', 'post_town']
    ],
    'county' => [
      ['district', 'county'],
      ['post_town', 'county'],
      ['county', 'county']
    ] 
  }

  POSTCODE_ADDRESS_PARENT_MAP = {
    unit: :dependent_thoroughfare_description,
    sector: :dependent_locality,
    district: :post_town
  }

  ADDRESS_POSTCODE_PARENT_MAP = {
    post_town: :area,
    dependent_locality: :district,
    thoroughfare_description: :district,
    dependent_thoroughfare_description: :district
  }

  def initialize(hash_str: str)
    @hash_str = hash_str
    @context_hash = self.class.construct_hash_from_hash_str(@hash_str)
    @level = type_of_str(@context_hash)
  end

  def type_of_str(hash)
    type = PropertySearchApi::ADDRESS_LOCALITY_LEVELS.reverse.select{ |t| hash[t] }.first
    postcode_locality_type ||= PropertySearchApi::POSTCODE_LEVELS.reverse.select { |e| hash[e] }.first
    if type == :post_town && ([:district, :sector, :unit].include?(postcode_locality_type))
      type = postcode_locality_type
    else
      type ||= postcode_locality_type
    end 
    hash[:type] = type
  end

  def self.form_hash(context_hash, type)
    if context_hash[:county].nil?
      context_hash[:county] = MatrixViewCount::COUNTY_MAP[context_hash[:post_town].upcase]
    end

    address_strs = []
    address_stop_index = postcode_stop_index = nil
    if PropertySearchApi::ADDRESS_LOCALITY_LEVELS.index(type)
      postcode_stop_level = ADDRESS_POSTCODE_PARENT_MAP[type]
      postcode_stop_level ||= :area
      address_stop_index = PropertySearchApi::ADDRESS_LOCALITY_LEVELS.index(type)
      postcode_stop_index = PropertySearchApi::POSTCODE_LEVELS.reverse.index(postcode_stop_level)
      postcode_stop_index ||= -1
    else
      address_stop_level = POSTCODE_ADDRESS_PARENT_MAP[type]
      postcode_stop_level = type
      address_stop_index = PropertySearchApi::ADDRESS_LOCALITY_LEVELS.index(address_stop_level)
      postcode_stop_index = PropertySearchApi::POSTCODE_LEVELS.reverse.index(type)
    end

    PropertySearchApi::ADDRESS_LOCALITY_LEVELS.each_with_index do |level, index|
      value = val(context_hash, level).to_s
      value = '@' if index > address_stop_index
      address_strs.push(value.to_s)
    end

    postcode_strs = []
    PropertySearchApi::POSTCODE_LEVELS.reverse.each_with_index do |level, index|
      value = val(context_hash, level)
      value = '@' if index > postcode_stop_index
      postcode_strs.push(value)
    end
    postcode_strs = [] if postcode_strs.all?{ |t| t == '@' }
    postcode_str = postcode_strs.reverse.join('_')
    postcode_str = nil if postcode_str.blank?
    location_strs = [ address_strs.join('_'), postcode_str ].compact
    result = location_strs.join('|')
    result = nil if context_hash[type].nil?
    result
  end

  def self.val(hash, key)
    val = hash[key]
    val ||= '@'
    val
  end

  def self.construct_hash_from_hash_str(hash)
    result_hash = {}
    address_levels = hash.split('|')[0]
    postcode_levels = hash.split('|')[1]
    if address_levels.split('_').length > 0 
      arr = address_levels.split('_')
      PropertySearchApi::ADDRESS_LOCALITY_LEVELS.each_with_index do |level, index|
        result_hash[level] = arr[index] if !arr[index].nil? && arr[index] != '@' 
      end 
    end 

    if postcode_levels && postcode_levels.split('_').length > 0 
      arr = postcode_levels.split('_')
      PropertySearchApi::POSTCODE_LEVELS.each_with_index do |level, index|
        if !arr[index].nil? && arr[index] != '@' 
          result_hash[level] = arr[index] 
          break
        end 
      end 
    end
    result_hash
  end

  def calculate_counts
    values = POSTCODE_MATCH_MAP[@level.to_s]
    values ||= ADDRESS_UNIT_MATCH_MAP[@level.to_s]
    final_results = {}
    @context_hash[:area] = calc_area_value(@context_hash[:district]) if @context_hash[:district]
    @context_hash[:district] = @context_hash[:sector].split(' ')[0] if @context_hash[:sector]
    @context_hash[:sector] = calc_sector_value(@context_hash[:unit]) if @context_hash[:unit]
    @context_hash[:district] = @context_hash[:sector].split(' ')[0] if @context_hash[:unit]
    values.each do |key, value|
      next if @context_hash[:post_town] == 'London' && key.to_sym == :dependent_locality
      calculate_count_for_level(key, value, final_results)
    end
    final_results
  end

  def calculate_counts_for_level(attribute)
    values = POSTCODE_MATCH_MAP[@level.to_s]
    values ||= ADDRESS_UNIT_MATCH_MAP[@level.to_s]
    attrs = values.map{ |t| t[0] }

    final_results = {}

    if attrs.include?(attribute.to_s)
      @context_hash[:area] = calc_area_value(@context_hash[:district]) if @context_hash[:district]
      @context_hash[:district] = @context_hash[:sector].split(' ')[0] if @context_hash[:sector]
      @context_hash[:sector] = calc_sector_value(@context_hash[:unit]) if @context_hash[:unit]
      @context_hash[:district] = @context_hash[:sector].split(' ')[0] if @context_hash[:unit]
      level = values[attrs.index(attribute.to_s)][1]
      calculate_count_for_level(attribute, level, final_results)
    end
    final_results
  end

  def calculate_count_for_level(attribute, level, final_results)
    matrix_view_context = @context_hash.clone

    ### To account for London districts(Not properly as counties)
    if matrix_view_context[:district] && matrix_view_context[:post_town] == 'London'
      matrix_view_context[:county] = MatrixViewCount.fetch_county_for_london(matrix_view_context[:district])
      @context_hash[:county] = matrix_view_context[:county]
    end

    ### We know that London doesn't have any dependent locality. Hence skip it if its London and key is dependent

    ### Counties can constraint and scope themselves
    matrix_view_context.delete(attribute.to_sym) if attribute.to_sym == @level && @level != :county

    #### throughfare and dependent are complimentary
    matrix_view_context.delete(:dependent_thoroughfare_description) if attribute.to_sym == :thoroughfare_description
    matrix_view_context.delete(:thoroughfare_description) if attribute.to_sym == :dependent_thoroughfare_description

    matrix_view_count = MatrixViewCount.new(
      scoping_parameter: attribute.to_sym, 
      constraint_key: level.to_sym, 
      constraints: matrix_view_context.clone,
      hash_str: self.class.form_hash(matrix_view_context, level.to_sym)
    )
    results = matrix_view_count.calculate_count
    final_results[attribute.to_s.pluralize] = results.map do |result_key, result_value|
      result_context = matrix_view_context
      result_context[attribute.to_sym] = result_key
      hash = {
        attribute.to_sym => result_key,
        flat_count: result_value,
        scoped_postcode: @context_hash[level.to_sym]
      }

      ### For districts having multiple post_tows, districts are by default scoped by post_town and seperated 
      ### in this step
      if attribute.to_sym == :district && level.to_sym == :county
        dist_post_town = hash[:district].split(', ')
        result_context[:post_town] = dist_post_town[1].strip
        result_context[:district] = dist_post_town[0].strip
      end

      hash[:hash_str] = self.class.form_hash(result_context, attribute.to_sym)
      hash
    end
  end

  def process_result
    count_hash = calculate_counts
    (PropertySearchApi::ADDRESS_LOCALITY_LEVELS-[:building_name, :building_number, :sub_building_name, :udprn]).each do |locality_level|
      count_hash[locality_level.to_s.pluralize] ||= []
      count_hash[locality_level] = @context_hash[locality_level]
      count_hash[locality_level] ||= nil
    end
    PropertySearchApi::POSTCODE_LEVELS.each do |postcode_level|
      count_hash[postcode_level.to_s.pluralize] ||= []
      count_hash[postcode_level] = @context_hash[postcode_level]
      count_hash[postcode_level] ||= nil
    end
    count_hash[:type] = @level
    count_hash
  end

  def process_result_for_level(attribute)
    count_hash = calculate_counts_for_level(attribute)
    (PropertySearchApi::ADDRESS_LOCALITY_LEVELS-[:building_name, :building_number, :sub_building_name, :udprn]).each do |locality_level|
      count_hash[locality_level.to_s.pluralize] ||= []
      count_hash[locality_level] = @context_hash[locality_level]
      count_hash[locality_level] ||= nil
    end
    PropertySearchApi::POSTCODE_LEVELS.each do |postcode_level|
      count_hash[postcode_level.to_s.pluralize] ||= []
      count_hash[postcode_level] = @context_hash[postcode_level]
      count_hash[postcode_level] ||= nil
    end
    count_hash[:type] = @level
    count_hash
  end

  def calc_area_value(district)
    index = district.index /[0-9]/
    district[0..index-1]
  end

  def calc_sector_value(unit)
    rindex = unit.rindex /[0-9]/
    unit[0..rindex]
  end

end

