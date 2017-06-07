module MatrixViewHelper
  POSTCODE_MATCH_MAP = {
      'unit' => [
        ['unit', 'sector'],
        ['dependent_thoroughfare_description', 'sector']
      ],
      'sector' => [
        ['unit', 'sector'],
        ['dependent_thoroughfare_description', 'sector'],
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
        ['unit', 'sector']
      ],
      'dependent_thoroughfare_description' => [
        ['dependent_thoroughfare_description', 'sector'],
        ['unit', 'sector']
      ],
      'dependent_locality' => [
        ['dependent_thoroughfare_description', 'dependent_locality'],
        ['dependent_locality', 'district'],
        ['sector', 'dependent_locality']
      ],
      'post_town' => [
        ['dependent_locality', 'post_town'],
        ['post_town', 'area'],
        ['district', 'area']
      ],
      'county' => [
        ['area', 'county'],
        ['post_town', 'county'],
        ['county', 'county']
      ]
  }
  def construct_aggs_query_from_fields(area, district, sector, unit, postcode_context, postcode_type, query, filter_index, search_type=:postcode, context_hash={})
    aggs = {}
    fields = ['area', 'county', 'post_town', 'district', 'dependent_locality', 'sector', 'dependent_thoroughfare_description', 'unit'].map(&:pluralize)
    search_type == :postcode ? match_map = POSTCODE_MATCH_MAP : match_map = ADDRESS_UNIT_MATCH_MAP
    match_map[postcode_type].each do |field_type|
      field = field_type[0]
      context = field_type[1]
      context_value = context_hash[context] || binding.local_variable_get(context)
      context_value = context_value.upcase if context == 'post_town'
      Rails.logger.info("#{aggs},#{field},#{context}, #{context_value}, #{context_hash}") 
      append_filtered_aggs(aggs, field, context, context_value)
    end
    query[:size] = 1
    query[:aggs] = aggs
    context_value = context_hash[postcode_context] || binding.local_variable_get(postcode_context)
    
    if query[:query][:filtered] && query[:query][:filtered][:filter] &&  query[:query][:filtered][:filter][:or]
      query[:query][:filtered][:filter][:or][:filters][filter_index][:and][:filters].push({ term: { postcode_context => context_value }})
    elsif query[:query][:filtered] && query[:query][:filtered][:filter] && query[:query][:filtered][:filter][:and]
      query[:query][:filtered][:filter][:and][:filters].push({ term: { postcode_context => context_value }})
      query[:query][:filtered][:filter][:and].delete(:or)
    end
  end

  def construct_response_body_postcode(area, district, sector, unit, es_response, postcode_type, search_type=:postcode, context_hash={})
    es_response = es_response.with_indifferent_access
    response_hash = {}
    response_hash[:type] = postcode_type
    fields = ['area', 'county', 'post_town', 'district', 'dependent_locality', 'sector', 'dependent_thoroughfare_description', 'unit']
    fields.map { |e| response_hash[e.pluralize] = [] }
    search_type == :postcode ? match_map = POSTCODE_MATCH_MAP : match_map = ADDRESS_UNIT_MATCH_MAP
    agg_fields = match_map[postcode_type]
    if es_response[:aggregations]
      agg_fields.each do |each_agg_field|
        context = context_hash[each_agg_field[1]] || binding.local_variable_get(each_agg_field[1])
        key_name = (each_agg_field[0]+"_aggs").to_sym
        if es_response[:aggregations][key_name] && es_response[:aggregations][key_name][key_name] && es_response[:aggregations][key_name][key_name][:buckets]
          es_response[:aggregations][key_name][key_name][:buckets].each do |value|
            response_hash[each_agg_field[0].pluralize].push({ each_agg_field[0] => value[:key], flat_count: value[:doc_count], scoped_postcode: context })
          end
        end
      end
    end
    construct_main_fields(response_hash, es_response)
    response_hash
  end

  def construct_main_fields(response_hash, es_response)
    fields = ['area', 'county', 'post_town', 'district', 'dependent_locality', 'sector', 'dependent_thoroughfare_description', 'unit']
    fields.map { |e| response_hash[e] = nil }
    if es_response[:hits] && es_response[:hits][:hits] && es_response[:hits][:hits].count > 0
      fields.each do |field|
        response_hash[field] = es_response[:hits][:hits].first[:_source][field]
      end
    end
  end
end
