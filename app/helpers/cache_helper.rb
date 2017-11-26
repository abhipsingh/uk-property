module CacheHelper
  def cache_response(cache_key, cache_parameters)
    #Rails.logger.info(params)
    latest_time = params[:latest_time].to_s
    if params[:latest_time]
      composite_key = cache_parameters.join('-')
      ardb_client = Rails.configuration.ardb_client
      value = ardb_client.hget("cache_#{cache_key}_#{action_name}", "#{composite_key}")
      epoch = Time.parse(params[:latest_time]).to_i
  
      if value && epoch < value.to_i
        latest_time = Time.at(value.to_i).to_s
        response.headers['latest_time'] = latest_time
        yield
      elsif value && epoch >= value.to_i
        latest_time = Time.at(epoch).to_s
        response.headers['latest_time'] = latest_time
        render nothing: true, status: 304
      else
        value = Time.now.to_i
        values = ardb_client.hset("cache_#{cache_key}_#{action_name}", "#{composite_key}", value)
        latest_time = Time.at(value).to_s
        response.headers['latest_time'] = latest_time
        yield
      end
    else
      latest_time = Time.now.to_s
      response.headers['latest_time'] = latest_time
      yield
    end
  end
end

