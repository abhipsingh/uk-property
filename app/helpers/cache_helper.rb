module CacheHelper
  def cache_response(cache_key, cache_parameters)
    @latest_time = params[:latest_time].to_s
    composite_key = cache_parameters.join('-')
    expected_value = composite_key + '-' + @latest_time
    ardb_client = Rails.configuration.ardb_client
    values = ardb_client.hget("cache_#{cache_key}", "#{action_name}_#{composite_key}")
    values = JSON.parse(values) rescue []
    values = [] if values.is_a?(String)
#    Rails.logger.info("EXISTING CACHE KEY #{cache_key}")
#    Rails.logger.info("EXISTING CACHE VALUES #{values}")
#    Rails.logger.info("EXISTING CACHE COMPOSITE VALUE #{expected_value}")
    rails_cache_key = expected_value

    if values.empty?
      @latest_time = Time.now.to_s.split("+")[0..-2].join.strip
      rails_cache_key = composite_key + '-' + @latest_time
      Rails.logger.info("EXISTING CACHE COMPOSITE KEY #{composite_key}")
    end

    if stale? rails_cache_key
      values.push(rails_cache_key)
      values = ardb_client.hset("cache_#{cache_key}", "#{action_name}_#{composite_key}", values.uniq.to_json)
      Rails.logger.info("NEW CACHE KEY #{cache_key}")
#      Rails.logger.info("NEW CACHE VALUES #{values}")
      yield
    end
    response.headers['latest_time'] = @latest_time
  end
end
