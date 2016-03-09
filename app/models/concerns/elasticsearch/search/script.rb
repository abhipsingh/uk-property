module Elasticsearch::Search::Script
  extend ActiveSupport::Concern

  #Append fields
  included do
    def append_script(key)
      @query[:script_fields] ||= {}
      @query[:script_fields].merge!(key)
      return self
    end
  end
end
