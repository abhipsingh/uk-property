module Elasticsearch::Search::Query
  extend ActiveSupport::Concern
  included do 

    # query
    def append_match_filter_query(field,value)
      match_query = { bool: { must: { query: { match: { field => value } } } } }
      build_query_hash(match_query)
      return self
    end

    # geo queries
    def append_geo_range_query(key, min_value = nil, max_value = nil, lat, lon)
      if min_value.nil? && max_value
        build_query_hash({ geo_distance_range:  { to: (max_value.to_f/1000.0).to_s + "km", key => {lat: lat.to_f, lon: lon.to_f}}}) 
      elsif min_value && max_value.nil?
        build_query_hash({ geo_distance_range: { from: (min_value.to_f/1000.0).to_s + "km", key => {lat: lat.to_f, lon: lon.to_f}}}) 
      elsif max_value && min_value
        build_query_hash({ geo_distance_range:  { from: (min_value.to_f/1000.0).to_s + "km", to: (max_value.to_f/1000.0).to_s + "km", key => {lat: lat.to_f, lon: lon.to_f}}}) 
      end
      return self
    end
    
    def append_geo_distance_filter_query(key,latitude,longitude,radius)
      unless @is_query_custom
        geo_query = {geo_distance: {key => {lat: latitude.to_f,lon: longitude.to_f},distance: radius,distance_type: :arc}}
        build_query_hash(geo_query)
        return self
      else
        raise "Cannot append geo_distance #{key} query since the query is custom"
      end
    end

    # polygon queries
    def append_geo_polygon_filter_query(key,array_lat_longs)
      geo_polygon_query = {geo_polygon: {key => {points: array_lat_longs}}}
      build_query_hash(geo_polygon_query)
      return self
    end

    def append_multi_geo_polygon_filter_query(key,multipolygon)
      should_query = Array.new
      multipolygon.each { |a| should_query.push({geo_polygon: {key => {points: a}}}) }
      should_query = { bool: { should: should_query } }
      build_query_hash(should_query)
      return self
    end

    def append_geo_polygon_nearby_filter_query(key,array_lat_longs_inner,array_lat_longs_outer)
      geo_polygon_inner_query = {geo_polygon: {key => {points: array_lat_longs_inner}}}
      geo_polygon_outer_query = {geo_polygon: {key => {points: array_lat_longs_outer}}}
      not_geo_polygon_inner_query = {not: geo_polygon_inner_query}
      build_query_hash(geo_polygon_outer_query)
      build_query_hash(not_geo_polygon_inner_query)
      return self
    end

    def append_bounding_box_filter_query(key,ne_lat_lng, sw_lat_lng)
      geo_query = {geo_bounding_box: {key => {top_right: {lat: ne_lat_lng[:latitude].to_f,
                                                          lon: ne_lat_lng[:longitude].to_f},
                                              bottom_left: {lat: sw_lat_lng[:latitude].to_f, 
                                                            lon: sw_lat_lng[:longitude].to_f }}}}
      build_query_hash(geo_query)
      return self
    end

    # scoring queries
    def append_query_sorting(sort_hash)
      @query[:query][:filtered][:query] = sort_hash
      return self
    end

    # unique version
    def append_unique_version_query(version)
      unique_query = { or: { filters: [ { terms: { versions: [ version ] } }, { and: { filters: [ { range: { min_version: { to: version } } }, { term: { head: true } } ] } } ] } }
      build_query_hash(unique_query)
      return self
    end

    def append_terms_filtered_query(field, values)
      unless @is_query_custom
        if values.is_a?(Array)
          build_query_hash({terms: {field => values}})
          return self
        else
          raise "Cannot append terms query to #{values} which is not an array"
        end
      else
        raise "Cannot append terms #{field} query since the query is custom"
      end
    end

  end

  def build_query_hash(query)
    @query[:query] = { filtered: { filter: { and: { filters: [] } } } }  if @query[:query].blank?
    @query[:query][:filtered][:filter][:and][:filters].push(query)
  end

  def build_aggs(aggs)
    @query[:aggs] = {} if @query[:aggs].blank?
    @query[:aggs].merge!(aggs)
  end
end
