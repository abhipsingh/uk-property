class MatrixViewCount
  attr_accessor :scoping_parameter, :constraint_key, :constraints

  POST_TOWNS = JSON.parse(File.read('county_map.json')).keys.uniq
  COUNTIES = JSON.parse(File.read('county_map.json')).values.uniq + [ 'Central London', 'East London', 'North West London', 'North London', 'South East London', 'South West London', 'Central London', 'West London' ]

  COLUMN_MAP = {
    county: 'county',
    post_town: 'pt',
    sector: 'sector',
    district: 'district',
    unit: 'postcode',
    dependent_locality: 'dl',
    thoroughfare_description: 'td',
    dependent_thoroughfare_description: 'dtd'
  }

  REVERSE_COLUMN_MAP = COLUMN_MAP.invert
  COUNTY_MAP = JSON.parse(File.read("county_map.json"))

  def initialize(scoping_parameter: scope, constraint_key: cons_key, constraints: cons_val, hash_str: hash)
    @scoping_parameter = scoping_parameter
    @constraint_key = constraint_key
    @constraints = constraints
    @hash_str = hash_str
  end

  def calculate_count
    result = nil
    if @constraint_key == :county
      ardb_client = Rails.configuration.ardb_client
      p @hash_str
      response = Oj.load(ardb_client.hget('mvc_cache_county', @hash_str+'_@'))
      if @scoping_parameter == :county
        result = {
          @constraints[:county] => response['count']
        }
      elsif @scoping_parameter == :post_town
        final_result = {}
        response['post_towns'].map do |post_town|
          final_result[post_town['pt']] = post_town['cnt']
        end
        result = final_result
      elsif @scoping_parameter == :district

        ### Go through all the post_towns and then go through the districts
        ### and aggregate(per post_town). Aggregate all post_town cache keys
        final_result = {}
        post_towns_hash_strs = response['post_towns'].map do |post_town|
          context_map =  { post_town: post_town['pt'], county: @constraints[:county] }
          MatrixViewService.form_hash_str(context_map, :post_town)
        end

        #### Get responses for all possible post_town cache keys
        #### Iterate through all of them and gather district data
        ### Also scope district name inside post_town
        pt_cache_response = ardb_client.hmget('mvc_cache_pt', *post_towns_hash_strs)
        pt_cache_response.each_with_index do |each_res, index|
          pt_response = Oj.load(each_res)
          pt = response['post_towns'][index]['pt']
          pt_response['districts'].map do |post_town|
            final_result["#{post_town['dt']}, #{pt}"] = post_town['cnt']
          end
        end
        result = final_result
      end

    #### When constraint is a post_town and group by district
    #### Simple and easy. Go through post_town cache and get district data
    #### Tweak county if post_town is London
    elsif @constraint_key == :post_town && @scoping_parameter == :district
      ardb_client = Rails.configuration.ardb_client
      pt_context = { county: COUNTY_MAP[@constraints[:post_town].upcase], post_town:  @constraints[:post_town]}
      pt_context[:county] = @constraints[:county] if @constraints[:county]
      pt_hash_key = MatrixViewService.form_hash_str(pt_context, :post_town)
      response = Oj.load(ardb_client.hget('mvc_cache_pt', pt_hash_key))
      final_result = {}
      response['districts'].map do |post_town|
        final_result[post_town['dt']] = post_town['cnt']
      end
      result = final_result
    elsif @constraint_key == :district && @scoping_parameter == :post_town
      ardb_client = Rails.configuration.ardb_client
      pt_context = { county: COUNTY_MAP[@constraints[:post_town].upcase], post_town:  @constraints[:post_town]}
      pt_context[:county] = self.class.fetch_county_for_london(@constraints[@constraint_key]) if @constraints[:post_town] == 'London'
      pt_hash_key = MatrixViewService.form_hash_str(pt_context, :post_town)
      response = Oj.load(ardb_client.hget('mvc_cache_pt', pt_hash_key))
      final_result = { @constraints[:post_town] => response['cnt'] }
      result = final_result
    else
      query = TestUkp
      @constraints.delete(:county)
      @constraints.delete(:area) if @constraints[:district]
      @constraints.each do |key, value|
        column_name = COLUMN_MAP[key]
        if key == :post_town
          pt_index = POST_TOWNS.index(value.upcase) + 1
          query = query.where("#{column_name} = ?", pt_index)
        elsif key == :county
          c_index = COUNTIES.index(value) + 1
          query = query.where("#{column_name} = ?", c_index)
        elsif key == :district
          query = query.where("to_tsvector('simple'::regconfig, postcode)  @@ to_tsquery('simple', '#{value}:*')")
        elsif key == :sector
          query = query.where("to_tsvector('simple'::regconfig, postcode)  @@ to_tsquery('simple', '#{value.split(' ').join('')}:*')")
        elsif key == :unit
          query = query.where("to_tsvector('simple'::regconfig, postcode)  @@ to_tsquery('simple', '#{value.split(' ').join('')}:*')")
        elsif key == :area
          query = query.where("to_tsvector('simple'::regconfig, postcode)  @@ to_tsquery('simple', '#{value}:*')")
        elsif key == :dependent_thoroughfare_description
          query = query.where("#{column_name} = ?", value)
          query = query.where("#{COLUMN_MAP[:dependent_locality]} IS NULL") if @constraints[:dependent_locality].nil?
        elsif key == :thoroughfare_description
          query = query.where("#{column_name} = ?", value)
          query = query.where("#{COLUMN_MAP[:dependent_locality]} IS NULL") if @constraints[:dependent_thoroughfare_description].nil?
        elsif key == :dependent_locality
          query = query.where("#{column_name} = ?", value)
        end
      end
      scope_column = COLUMN_MAP[@scoping_parameter.to_sym]
      query = query.select("#{scope_column}")
      p query.to_sql
      result = query.group("#{scope_column}").count.select{ |h,k| h }
      if scope_column.to_sym == :postcode
        unit_result = {}
        result.each do |key, value|
          rindex = key.rindex /[0-9]/
          unit_result[(key[0..rindex-1] + ' ' + key[rindex..-1])] = value
        end
        result = unit_result
      end
    end

    result    
  end

  def self.fetch_county_for_london(district)
    if district.start_with?('EC')
      'Central London'
    elsif district.start_with?('E')
      'East London'
    elsif district.start_with?('NW')
      'North West London'
    elsif district.start_with?('N')
      'North London'
    elsif district.start_with?('SE')
      'South East London'
    elsif district.start_with?('SW')
      'South West London'
    elsif district.start_with?('WC')
      'Central London'
    elsif district.start_with?('W')
      'West London'
    end
  end

end
