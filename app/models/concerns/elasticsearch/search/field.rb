module Elasticsearch::Search::Field
  extend ActiveSupport::Concern

  #Append fields
  included do
    def append_fields_native_query(key)
      @query[:fields] ||= []
      @query[:fields] |= [key]
      return self
    end
  end
end
