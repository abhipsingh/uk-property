module CacheHelper
  def cache_response(cache_key, cache_parameters)
    Rails.logger.info(params)
    if params[:latest_time].to_s == "true"
      @latest_time = params[:latest_time].to_s
      composite_key = cache_parameters.join('-')
      expected_value = composite_key + '-' + @latest_time
      ardb_client = Rails.configuration.ardb_client
      values = ardb_client.hget("cache_#{cache_key}_#{action_name}", "#{composite_key}")
      values = JSON.parse(values) rescue []
      values = [] if values.is_a?(String)
      rails_cache_key = expected_value
  
      if values.empty?
        @latest_time = Time.now.to_s.split("+")[0..-2].join.strip
        rails_cache_key = composite_key + '-' + @latest_time
        Rails.logger.info("NOT FOUND CACHE COMPOSITE KEY #{composite_key}")
        values.push(rails_cache_key)
        values = ardb_client.hset("cache_#{cache_key}_#{action_name}", "#{composite_key}", values.uniq.to_json)
        yield
      else
        Rails.logger.info("EXISTING CACHE COMPOSITE KEY #{composite_key}")
        render nothing: true, status: 304
      end
    else
      yield
    end
    response.headers['latest_time'] = @latest_time
  end
end

