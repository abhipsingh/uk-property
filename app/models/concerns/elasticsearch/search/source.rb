module Elasticsearch::Search::Source
  extend ActiveSupport::Concern
  included do 
    
    def append_fields_query(fields=[])
      raise "Fields should be an array" unless fields.is_a? Array
      if @query[:_source].nil?
        @query[:_source] = {include: fields}
      else
        existing_fields = (@query[:_source][:include] or [])
        @query[:_source][:include] = existing_fields.concat(fields).uniq
      end
      return self
    end

    def exclude_fields_query(fields=[])
      raise "Fields should be an array" unless fields.is_a? Array
      if @query[:_source].nil?
        @query[:_source] = {exclude: fields}
      else
        existing_fields = (@query[:_source][:exclude] or [])
        build_existing_fields.concat(fields).uniq
      end
      return self
    end

  end
end
