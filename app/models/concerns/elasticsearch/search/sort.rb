module Elasticsearch::Search::Sort
  extend ActiveSupport::Concern
  included do 

    def append_field_sorting(key,order)
      sort_hash = {key => {order: order.downcase}}
      build_sort_hash(sort_hash)
      return self
    end

    def append_custom_sorting(sort_query_hash)
      @query[:sort] = sort_query_hash
      return self
    end

    def append_geo_distance_sorting(key,latitude,longitude,order)
      geo_sort_query  = {
        _geo_distance: {
          key => [latitude.to_f,longitude.to_f],
          order: order,
          unit: :km
        }
      }
      build_sort_hash(geo_sort_query)
      return self
    end

  end

  def build_sort_hash(sort)
    @query[:sort] = [] if @query[:sort].nil?
    @query[:sort].push(sort)
  end
end
