module Elasticsearch::Search::Filter
  extend ActiveSupport::Concern
  included do

    # basic filters
    def append_term_filter_query(field,value)
      unless @is_query_custom 
        build_filter_hash(field,{term: {field => value}}) 
        return self
      else
        raise "Cannot append term #{field} query since the query is custom"
      end
    end

    def append_terms_filter_query(field,values)
      unless @is_query_custom
        if values.is_a?(Array)
          build_filter_hash(field,{terms: {field => values}})
          return self
        else
          raise "Cannot append terms query to #{values} which is not an array"
        end
      else
        raise "Cannot append terms #{field} query since the query is custom"
      end
    end

    def append_range_filter_query(field,min_value = nil,max_value = nil)
      unless @is_query_custom
        if min_value.nil? && max_value
          build_filter_hash(field,{ range: { field => { to: max_value}}}) 
        elsif min_value && max_value.nil?
          build_filter_hash(field,{ range: { field => { from: min_value}}}) 
        elsif max_value && min_value
          build_filter_hash(field,{ range: { field => { from: min_value ,to: max_value}}}) 
        end
        return self
      else
        raise "Cannot append range #{key} query since the query is custom"
      end
    end

    def build_filter_hash(field,filter)
      @query[:filter] = { and: { filters: [] } }  if @query[:filter].blank?
      @query[:filter][:and][:filters].push(filter)
      append_filter_aggregation(field,filter) if @is_agg_filtered
    end

  end 

end
