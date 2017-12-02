module Elasticsearch::Search
  extend ActiveSupport::Concern
  included do 
    include Elasticsearch::Search::Query
    include Elasticsearch::Search::Filter
    include Elasticsearch::Search::Sort
    include Elasticsearch::Search::Agg
    include Elasticsearch::Search::Source
    include Elasticsearch::Search::Field
    include Elasticsearch::Search::Script

    attr_accessor :query,:filtered_params,:fields,:is_agg_filtered, :is_query_custom
    def initialize(options = {filtered_params: {}, query: self.class.append_empty_hash, is_query_custom: false})
      @filtered_params = options[:filtered_params].symbolize_keys
      @query = self.class.append_empty_hash
      @query = options[:query] if @is_query_custom == true
    end
  end

  module ClassMethods
    def append_empty_hash
      {
        size: 10000
      }
    end
  end

end

