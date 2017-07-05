module CacheHelper
  def cache_response(cache_key, cache_parameters)
    latest_time = params[:latest_time].to_s
    composite_key = cache_parameters.join('-')
    expected_value = composite_key + '-' + latest_time
    values = Rails.cache.read("#{action_name}_#{cache_key}")
#    Rails.logger.info("EXISTING CACHE KEY #{cache_key}")
#    Rails.logger.info("EXISTING CACHE VALUES #{values}")
#    Rails.logger.info("EXISTING CACHE COMPOSITE VALUE #{expected_value}")
    rails_cache_key = expected_value

    if values.nil? || !values.is_a?(Array) || !values.include?(expected_value)
      latest_time = Time.now.to_s.split("+")[0..-2].join.strip
      rails_cache_key = composite_key + '-' + latest_time
      Rails.logger.info("EXISTING CACHE COMPOSITE KEY #{composite_key}")
    end

    if stale? rails_cache_key
      values = Rails.cache.read("#{action_name}_#{cache_key}")
      values = [ rails_cache_key ] if values.nil?
      values.push(rails_cache_key) if values.is_a?(Array)
      Rails.cache.write("#{action_name}_#{cache_key}", values.uniq)
#      Rails.logger.info("NEW CACHE KEY #{cache_key}")
#      Rails.logger.info("NEW CACHE VALUES #{values}")
      yield
    end
    response.headers['latest_time'] = latest_time
  end
end
