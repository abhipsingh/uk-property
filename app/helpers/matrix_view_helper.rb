module MatrixViewHelper
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
        ['district', 'area']
      ],
      'area' => [
        ['area', 'area'],
        ['post_town', 'area'],
        ['district', 'area'],
        ['county', 'area']
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



  def construct_aggs_query_from_fields(area, district, sector, unit, postcode_context, postcode_type, query, filter_index, context_hash={}, search_type=:postcode)
    aggs = {}
    fields = ['area', 'county', 'post_town', 'district', 'dependent_locality', 'sector', 'thoroughfare_description', 'dependent_thoroughfare_description', 'unit'].map(&:pluralize)
    search_type == :postcode ? match_map = POSTCODE_MATCH_MAP : match_map = ADDRESS_UNIT_MATCH_MAP
    context_hash = context_hash.with_indifferent_access
    match_map[postcode_type.to_s].each do |field_type|
      field = field_type[0]
      context = field_type[1]
      context_value = context_hash[context] || binding.local_variable_get(context)
      context_value = context_value if context == 'post_town'
      # Rails.logger.info("#{aggs},#{field},#{context}, #{context_value}, #{context_hash}") 
      append_filtered_aggs(aggs, field, context, context_value)
    end
    query[:size] = 0
    query[:aggs] = aggs
    context_value = context_hash[postcode_context] || binding.local_variable_get(postcode_context)
    
    if query[:query][:filtered] && query[:query][:filtered][:filter] &&  query[:query][:filtered][:filter][:or]
      query[:query][:filtered][:filter][:or][:filters][filter_index][:and][:filters].push({ term: { postcode_context => context_value }}) if !context_value.blank?
    elsif query[:query][:filtered] && query[:query][:filtered][:filter] && query[:query][:filtered][:filter][:and]
      query[:query][:filtered][:filter][:and][:filters].push({ term: { postcode_context => context_value }}) if !context_value.blank?
      query[:query][:filtered][:filter][:and].delete(:or)
    end
  end

  def construct_response_body_postcode(area, district, sector, unit, es_response, postcode_type, search_type=:postcode, context_hash={}, address_map={})
    es_response = es_response.with_indifferent_access
    response_hash = {}
    response_hash[:type] = postcode_type
    fields = ['area', 'county', 'post_town', 'district', 'dependent_locality', 'sector', 'thoroughfare_description', 'dependent_thoroughfare_description', 'unit']
    fields.map { |e| response_hash[e.pluralize] = [] }
    search_type == :postcode ? match_map = POSTCODE_MATCH_MAP : match_map = ADDRESS_UNIT_MATCH_MAP
    agg_fields = match_map[postcode_type.to_s]
    if es_response[:aggregations]
      agg_fields.each do |each_agg_field|
        context = context_hash[each_agg_field[1]] || binding.local_variable_get(each_agg_field[1])
        key_name = (each_agg_field[0]+"_aggs").to_sym
        if es_response[:aggregations][key_name] && es_response[:aggregations][key_name][key_name] && es_response[:aggregations][key_name][key_name][:buckets]
          es_response[:aggregations][key_name][key_name][:buckets].each do |value|
            new_context_map = context_hash.clone
            new_context_map[each_agg_field[0].to_sym] = value[:key]
            new_context_map[each_agg_field[1].to_sym] = context
            new_context_map[:scoping_type] = each_agg_field[1].to_sym
            hash_str = nil
            if PropertySearchApi::ADDRESS_LOCALITY_LEVELS.include?(each_agg_field[1].to_sym)
              hash_str = MatrixViewService.form_hash_str(new_context_map, each_agg_field[0].to_sym)
            else
              hash_str = MatrixViewService.form_hash(new_context_map, each_agg_field[0].to_sym)
            end
            response_hash[each_agg_field[0].pluralize].push({ each_agg_field[0] => value[:key], flat_count: value[:doc_count], scoped_postcode: context, hash_str: hash_str })
          end
        end
      end
    end
    construct_main_fields(response_hash, es_response, address_map)
    response_hash
  end

  def construct_main_fields(response_hash, es_response, address_map)
    fields = ['area', 'county', 'post_town', 'district', 'dependent_locality', 'sector',  'thoroughfare_description','dependent_thoroughfare_description', 'unit']
    fields.map { |e| response_hash[e] = nil }
      first_doc = address_map
      first_doc = first_doc.with_indifferent_access
      fields.each do |field|
        response_hash[field] = first_doc[field]
      end
  end

  def type_of_str(hash)
    type = PropertySearchApi::ADDRESS_LOCALITY_LEVELS.reverse.select{ |t| hash[t] }.first
    postcode_locality_type ||= PropertySearchApi::POSTCODE_LEVELS.reverse.select { |e| hash[e] }.first
    if type == :post_town && postcode_locality_type == :district
      type = :district
    else
      type ||= postcode_locality_type
    end
    hash[:type] = type
  end

  def form_hash_str(context_hash, type)
    if type == :county
      "#{context_hash[:county]}_@_@_@_@_@_@_@_@"
    elsif type == :post_town
      county = context_hash[:county]
      county = '@' if county.nil?
      "#{county}_#{context_hash[:post_town]}_@_@_@_@_@_@_@"
    elsif type == :dependent_locality
      pt = context_hash[:post_town]
      pt = '@' if pt.blank?
      district = context_hash[:district]
      district = '@' if district.nil?
      "@_#{pt}_#{context_hash[:dependent_locality]}_@_@_@_@_@_@|@_@_#{district}"
    elsif type == :dependent_thoroughfare_description
      pt = context_hash[:post_town]
      pt = '@' if pt.blank?
      dl = "#{context_hash[:dependent_locality]}"
      dl = "@" if dl == ''
      sector = context_hash[:sector]
      sector = '@' if sector.blank?
      "@_#{pt}_#{dl}_@_#{context_hash[:dependent_thoroughfare_description]}_@_@_@_@|@_#{sector}_#{context_hash[:district]}"
    elsif type == :thoroughfare_description
      pt = context_hash[:post_town]
      pt = '@' if pt.blank?
      dl = "#{context_hash[:dependent_locality]}"
      dl = "@" if dl == ''
      sector = context_hash[:sector]
      sector = '@' if sector.blank?
      "@_#{pt}_#{dl}_#{context_hash[:thoroughfare_description]}_@_@_@_@_@|@_#{sector}_#{context_hash[:district]}"
    elsif type == :district
      area = context_hash[:area]
      pt = context_hash[:post_town]
      !area.nil? ? pt = '@' : pt = pt
      pt = '@' if pt.blank?
      "@_#{pt}_@_@_@_@_@_@_@|@_@_#{context_hash[:district]}"
    elsif type == :sector
      dl = "#{context_hash[:dependent_locality]}"
      dl = "@" if dl == ''
      "@_@_#{dl}_@_@_@_@_@_@|@_#{context_hash[:sector]}_@"
    elsif type == :unit
      "@_@_@_@_@_@_@_@_@|#{context_hash[:unit]}_@_@"
    end
  end

  def calculate_postcode_units(hash)

  end
end
