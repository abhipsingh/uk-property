module Elasticsearch::Search::Agg
  extend ActiveSupport::Concern
  included do 
    def generate_aggregation(params, type= "terms")
      aggregations = {}
      params.each do |field|
        aggs_hash = {}
        if type == "terms"
          aggs_hash = generate_aggs_hash("terms", options: {name: "#{field}_aggs", field: field})
        elsif type == "metric"
          metric_type, attribute = field.split("_") rescue []
          aggs_hash = generate_aggs_hash("metric", options: {name: field, field: attribute, type: metric_type}) if (metric_type && attribute)
        elsif type == 'histogram'
          aggs_hash = generate_aggs_hash(type, options:{name: "#{field[0]}_aggs", field: field[0], interval: field[1]})
        end
        aggregations.merge!(aggs_hash)
        # agg = self.send("append_#{type}_aggregation",{:name => name, :field => field})
      end
      return aggregations
    end

    def generate_aggs_hash(type, options: {})
      agg = nil
      if type == "terms"
        agg = self.send("append_terms_aggregation",{name: options[:name], field: options[:field]})
      elsif type == "metric"
        agg = self.send("append_metric_aggregation",{name: options[:name], field: options[:field], type: options[:type]})
      elsif type == 'histogram'
        agg = self.send("append_#{type}_aggregation",{name: options[:name], field: options[:field], interval: options[:interval]})
      end
      aggs_hash = { options[:name] => { aggs: agg, filter: { and: { filters: [] } } } } if agg
      aggs_hash ||= {}
    end

    def append_filter_aggregation(field,filter)
      name = "#{field}_aggs"
      @aggregations.each{ |k,v| v[:filter][:and][:filters].push(filter) unless (name == k)}
    end

    def filter_aggregations(filter_hash)
      raise "Not a Hash" unless filter_hash.is_a?(Hash)
      append_filtered_aggregation aggs_hash: self.query[:aggs], filter_hash: filter_hash, name: :filtered_aggs
    end

    def append_terms_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      field = options[:field]
      order_key = options[:order_key]
      order_value = options[:order_value]
      name = options[:name]
      size = options[:size]
      min_doc_count = options[:min_doc_count]
      nested_aggs = options[:nested_aggs]
      aggs_hash = {
        name => {
          terms: {
            field: field,
            size: 25
          }
        }
      }
      aggs_hash[name][:terms][:order] = { order_key => order_value } if order_value && order_key
      aggs_hash[name][:terms][:size] = size if size
      aggs_hash[name][:terms][:min_doc_count] = min_doc_count if min_doc_count
      aggs_hash[name][:aggs] = nested_aggs[:aggs] if nested_aggs
      return aggs_hash
    end

    def append_geo_hash_grid_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      name = options[:name]
      field = options[:field]
      nested_aggs = options[:nested_aggs]
      precision = options[:precision]
      aggs_hash = {
        name => {
          geohash_grid: {
            field: field,
            precision: precision
          }

        }
      }
      aggs_hash[name][:aggs] = nested_aggs[:aggs] if nested_aggs
      return aggs_hash
    end

    def append_top_hits_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      name = options[:name]
      sort_key = options[:sort_key]
      sort_order = options[:sort_order]
      fields = options[:fields]
      size = options[:size]
      aggs_hash = {
        name => {
          top_hits: {

          }

        }
      }
      aggs_hash[name][:top_hits][:sort] = [{sort_key => { order: sort_order}}] if sort_order && sort_key
      aggs_hash[name][:top_hits][:_source] = {include: fields} if fields
      aggs_hash[name][:top_hits][:size] = size if size
      return aggs_hash
    end

    def append_date_histogram_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      name = options[:name]
      field = options[:field]
      interval = options[:interval]
      nested_aggs = options[:nested_aggs]
      min_doc_count = options[:min_doc_count]
      aggs_hash = {
        name => {
          date_histogram: {
            field: field,
            interval: interval
          }

        }
      }
      aggs_hash[name][:date_histogram][:min_doc_count] = min_doc_count
      aggs_hash[name][:aggs] = nested_aggs[:aggs] if nested_aggs
      return aggs_hash
    end

    def append_histogram_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      name = options[:name]
      sort_key = options[:sort_key]
      sort_order = options[:sort_order]
      field = options[:field]
      interval = options[:interval]
      size = options[:size]
      min_doc_count = options[:min_doc_count]
      nested_aggs = options[:nested_aggs]
      aggs_hash = {
        name => {
          histogram: {
            field: field,
            interval: interval
          }

        }
      }
      aggs_hash[name][:aggs] = nested_aggs[:aggs] if nested_aggs
      aggs_hash[name][:histogram][:order] = {sort_key => sort_order} if sort_order && sort_key
      aggs_hash[name][:histogram][:min_doc_count] = min_doc_count if min_doc_count
      return aggs_hash
    end

    def append_date_range_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      name = options[:name]
      field = options[:field]
      range_array = options[:range_array]
      nested_aggs = options[:nested_aggs]
      aggs_hash = {
        name => {
          date_range: {
            field: field,
            format: "yyyy-mm-dd",
            ranges: []
          }

        }
      }
      range_array.each do |range|
        if range[0] && range[1]
          aggs_hash[name][:date_range][:ranges]  |= [{ from: range[0], to: range[1]}]
        elsif range[0].nil? && range[1]
          aggs_hash[name][:date_range][:ranges] |= [{ to: range[1]}]
        elsif range[0] && range[1].nil?
          aggs_hash[name][:date_range][:ranges] |= [{ from: range[0]}]
        end
      end
      aggs_hash[name][:aggs] = nested_aggs[:aggs] if nested_aggs
      return aggs_hash
    end

    def append_range_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      name = options[:name]
      field = options[:field]
      range_array = options[:range_array]
      nested_aggs = options[:nested_aggs]
      keyed = options[:keyed]
      aggs_hash = {
        name => {
          range: {
            field: field,
            ranges: []
          }

        }
      }
      aggs_hash[name][:range][:keyed] = true if keyed && keyed == true
      range_array.each do |range|
        if range[0] && range[1]
          if keyed
            aggs_hash[name][:range][:ranges] |= [{ from: range[0], to: range[1], key: range[2]}]
          else
            aggs_hash[name][:range][:ranges] |= [{ from: range[0], to: range[1]}]
          end
        elsif range[0].nil? && range[1]
          if keyed
            aggs_hash[name][:range][:ranges] |= [{ to: range[1], key: range[2]}]
          else
            aggs_hash[name][:range][:ranges] |= [{ to: range[1]}]
          end
        elsif range[0] && range[1].nil?
          if keyed
            aggs_hash[name][:range][:ranges] |= [{ from: range[0], key: range[2]}]
          else
            aggs_hash[name][:range][:ranges] |= [{ from: range[0]}]
          end
        end
      end
      aggs_hash[name][:aggs] = nested_aggs[:aggs] if nested_aggs
      return aggs_hash
    end

    def append_nested_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      query = options[:query]
      name = options[:name]
      path = options[:path]
      aggs_hash = {
        name => {
          nested: {
            path: path
          },
          aggs: query[:aggs]
        }
      }
      return aggs_hash
    end

    def append_cardinality_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      field = options[:field]
      name = options[:name]
      rehash_value = options[:rehash_value]
      precision_threshold = options[:precision_threshold]
      aggs_hash = {
        name => {
          value_count: {
            field: field
          }
        }
      }
      aggs_hash[name][:rehash] = rehash_value if rehash_value 
      aggs_hash[name][:precision_threshold] = precision_threshold if precision_threshold 
      return aggs_hash
    end

    def append_value_count_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      field = options[:field]
      name = options[:name]
      aggs_hash = {
        name => {
          value_count: {
            field: field
          }
        }
      }
      return aggs_hash
    end

    def append_metric_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      type = options[:type]
      name = options[:name]
      field = options[:field]
      aggs_hash = {
        name => {
          type => {
            field: field
          }

        }
      }
      return aggs_hash
    end

    def append_geo_distance_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      puts options.to_json
      name = options[:name]
      field = options[:field]
      origin = options[:coordinates]
      nested_aggs = options[:nested_aggs]
      range_array = options[:range_array]
      aggs_hash = {
        name => {
          geo_distance: {
            field: field,
            origin: origin,
            ranges: []
          }

        }
      }
      range_array.each do |range|
        if range[0] && range[1]
          aggs_hash[name][:geo_distance][:ranges] |= [{ from: range[0], to: range[1]}]
        elsif range[0].nil? && range[1]
          aggs_hash[name][:geo_distance][:ranges] |= [{ to: range[1]}]
        elsif range[0] && range[1].nil?
          aggs_hash[name][:geo_distance][:ranges] |= [{ from: range[0]}]
        end
      end
      aggs_hash[name][:aggs] = nested_aggs[:aggs] if nested_aggs
      return aggs_hash
    end

    def append_filtered_aggregation(options)
      raise "Not a valid Hash " unless options.is_a?(Hash)
      name = options[:name]
      aggs_hash = options[:aggs_hash]
      filter_hash = options[:filter_hash]
      aggs = {
        name => {
          aggs: aggs_hash
        }
      }
      aggs[name].merge!(filter_hash)
      return aggs
    end
    
  end

end
